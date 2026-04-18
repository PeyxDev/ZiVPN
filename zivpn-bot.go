package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	tgbotapi "github.com/go-telegram-bot-api/telegram-bot-api/v5"
)

// ==========================================
// Constants & Configuration
// ==========================================

const (
	BotConfigFile = "/etc/zivpn/bot-config.json"
	ApiUrl        = "http://127.0.0.1:8585/api"
	ApiKeyFile    = "/etc/zivpn/apikey"
	DomainFile    = "/etc/zivpn/domain"
	TrialDuration = 1 // 1 days trial
	TrialLimit    = 1 // 1 device for trial
)

var ApiKey = "AutoFtBot-agskjgdvsbdreiWG1234512SDKrqw"

type BotConfig struct {
	BotToken      string `json:"bot_token"`
	AdminID       int64  `json:"admin_id"`
	Mode          string `json:"mode"`   // "public" or "private"
	Domain        string `json:"domain"` // Domain from setup
	DailyPrice    int    `json:"daily_price"`
	PakasirSlug   string `json:"pakasir_slug"`
	PakasirApiKey string `json:"pakasir_api_key"`
}

type IpInfo struct {
	City string `json:"city"`
	Isp  string `json:"isp"`
}

type UserData struct {
	Password string `json:"password"`
	Expired  string `json:"expired"`
	Status   string `json:"status"`
	IpLimit  int    `json:"ip_limit"`
}

// ==========================================
// Global State
// ==========================================

var userStates = make(map[int64]string)
var tempUserData = make(map[int64]map[string]string)
var lastMessageIDs = make(map[int64]int)
var trialUsers = make(map[int64]bool) // Track users who already claimed trial

// ==========================================
// Main Entry Point
// ==========================================

func main() {
	// Load API Key
	if keyBytes, err := ioutil.ReadFile(ApiKeyFile); err == nil {
		ApiKey = strings.TrimSpace(string(keyBytes))
	}

	// Load Config
	config, err := loadConfig()
	if err != nil {
		log.Fatal("Gagal memuat konfigurasi bot:", err)
	}

	// Initialize Bot
	bot, err := tgbotapi.NewBotAPI(config.BotToken)
	if err != nil {
		log.Panic(err)
	}

	bot.Debug = false
	log.Printf("Authorized on account %s", bot.Self.UserName)

	u := tgbotapi.NewUpdate(0)
	u.Timeout = 60
	updates := bot.GetUpdatesChan(u)

	// Main Loop
	for update := range updates {
		if update.Message != nil {
			handleMessage(bot, update.Message, &config)
		} else if update.CallbackQuery != nil {
			handleCallback(bot, update.CallbackQuery, &config)
		}
	}
}

// ==========================================
// Telegram Event Handlers
// ==========================================

func handleMessage(bot *tgbotapi.BotAPI, msg *tgbotapi.Message, config *BotConfig) {
	// Access Control
	if !isAllowed(config, msg.From.ID) {
		replyError(bot, msg.Chat.ID, "⛔ Akses Ditolak. Bot ini Private.")
		return
	}

	// Handle State (User Input)
	if state, exists := userStates[msg.From.ID]; exists {
		handleState(bot, msg, state, config)
		return
	}

	// Handle Commands
	if msg.IsCommand() {
		switch msg.Command() {
		case "start":
			showMainMenu(bot, msg.Chat.ID, config)
		default:
			replyError(bot, msg.Chat.ID, "❌ Perintah tidak dikenal.")
		}
	}
}

func handleCallback(bot *tgbotapi.BotAPI, query *tgbotapi.CallbackQuery, config *BotConfig) {
	// Access Control (Special case for toggle_mode)
	if !isAllowed(config, query.From.ID) {
		if query.Data != "toggle_mode" || query.From.ID != config.AdminID {
			bot.Request(tgbotapi.NewCallback(query.ID, "Akses Ditolak"))
			return
		}
	}

	chatID := query.Message.Chat.ID
	userID := query.From.ID

	switch {
	// --- Menu Navigation ---
	case query.Data == "menu_create":
		startCreateUser(bot, chatID, userID)
	case query.Data == "menu_trial":
		handleTrialRequest(bot, chatID, userID, config)
	case query.Data == "menu_delete":
		showUserSelection(bot, chatID, 1, "delete")
	case query.Data == "menu_renew":
		showUserSelection(bot, chatID, 1, "renew")
	case query.Data == "menu_list":
		listUsers(bot, chatID)
	case query.Data == "menu_info":
		systemInfo(bot, chatID, config)
	case query.Data == "menu_pricing":
		showPricing(bot, chatID, config)
	case query.Data == "cancel":
		cancelOperation(bot, chatID, userID, config)
	case query.Data == "back_menu":
		showMainMenu(bot, chatID, config)

	// --- Pagination ---
	case strings.HasPrefix(query.Data, "page_"):
		handlePagination(bot, chatID, query.Data)

	// --- Action Selection ---
	case strings.HasPrefix(query.Data, "select_renew:"):
		startRenewUser(bot, chatID, userID, query.Data)
	case strings.HasPrefix(query.Data, "select_delete:"):
		confirmDeleteUser(bot, chatID, query.Data)

	// --- Action Confirmation ---
	case strings.HasPrefix(query.Data, "confirm_delete:"):
		username := strings.TrimPrefix(query.Data, "confirm_delete:")
		deleteUser(bot, chatID, username, config)

	// --- Admin Actions ---
	case query.Data == "toggle_mode":
		toggleMode(bot, chatID, userID, config)
	}

	bot.Request(tgbotapi.NewCallback(query.ID, ""))
}

func handleState(bot *tgbotapi.BotAPI, msg *tgbotapi.Message, state string, config *BotConfig) {
	userID := msg.From.ID
	text := strings.TrimSpace(msg.Text)
	chatID := msg.Chat.ID

	switch state {
	case "create_username":
		if !validateUsername(bot, chatID, text) {
			return
		}
		tempUserData[userID]["username"] = text
		userStates[userID] = "create_days"
		sendModernMessage(bot, chatID, "⏳ **Masukkan Durasi (Hari)**\n\n💰 Harga: *Rp "+formatRupiah(config.DailyPrice)+"*/hari\n📅 Min: 1 hari - Max: 365 hari", nil)

	case "create_days":
		days, ok := validateNumber(bot, chatID, text, 1, 365, "Durasi")
		if !ok {
			return
		}
		tempUserData[userID]["days"] = text
		userStates[userID] = "create_limit"
		sendModernMessage(bot, chatID, "💻 **Masukkan Max Login (1-100)**\n\n⚠️ Jumlah device yang bisa login bersamaan", nil)

	case "create_limit":
		limit, ok := validateNumber(bot, chatID, text, 1, 100, "Limit")
		if !ok {
			return
		}
		days, _ := strconv.Atoi(tempUserData[userID]["days"])
		createUser(bot, chatID, tempUserData[userID]["username"], days, limit, config)
		resetState(userID)

	case "renew_days":
		days, ok := validateNumber(bot, chatID, text, 1, 365, "Durasi")
		if !ok {
			return
		}
		renewUser(bot, chatID, tempUserData[userID]["username"], days, config)
		resetState(userID)

	case "trial_username":
		if !validateUsername(bot, chatID, text) {
			return
		}
		tempUserData[userID]["username"] = text
		createTrialAccount(bot, chatID, userID, config)
	}
}

// ==========================================
// Modern UI Components
// ==========================================

func showMainMenu(bot *tgbotapi.BotAPI, chatID int64, config *BotConfig) {
	ipInfo, _ := getIpInfo()
	domain := config.Domain
	if domain == "" {
		domain = "✨ Premium Service"
	}

	// Modern welcome message with box design
	welcomeMsg := fmt.Sprintf(
		"┌─────────────────────────────────┐\n"+
			"│      🚀 **ZIVPN PREMIUM** 🚀      │\n"+
			"├─────────────────────────────────┤\n"+
			"│ 🌐 *Domain*   : %s\n"+
			"│ 📍 *City*     : %s\n"+
			"│ 🔌 *ISP*      : %s\n"+
			"├─────────────────────────────────┤\n"+
			"│   🎯 *Fast • Stable • Secure*    │\n"+
			"└─────────────────────────────────┘\n\n"+
			"✨ *Welcome to the best VPN service!* ✨",
		domain, ipInfo.City, ipInfo.Isp)

	msg := tgbotapi.NewMessage(chatID, welcomeMsg)
	msg.ParseMode = "Markdown"
	msg.ReplyMarkup = getMainMenuKeyboard(config)
	sendAndTrack(bot, msg)
}

func getMainMenuKeyboard(config *BotConfig) tgbotapi.InlineKeyboardMarkup {
	modeLabel := "🔐 Mode: Private"
	if config.Mode == "public" {
		modeLabel = "🌍 Mode: Public"
	}

	return tgbotapi.NewInlineKeyboardMarkup(
		tgbotapi.NewInlineKeyboardRow(
			tgbotapi.NewInlineKeyboardButtonData("🛒 **BUY PREMIUM**", "menu_create"),
			tgbotapi.NewInlineKeyboardButtonData("🎁 **FREE TRIAL**", "menu_trial"),
		),
		tgbotapi.NewInlineKeyboardRow(
			tgbotapi.NewInlineKeyboardButtonData("🗑️ Delete Account", "menu_delete"),
			tgbotapi.NewInlineKeyboardButtonData("🔄 Renew Account", "menu_renew"),
		),
		tgbotapi.NewInlineKeyboardRow(
			tgbotapi.NewInlineKeyboardButtonData("📋 List Accounts", "menu_list"),
			tgbotapi.NewInlineKeyboardButtonData("💰 Pricing", "menu_pricing"),
		),
		tgbotapi.NewInlineKeyboardRow(
			tgbotapi.NewInlineKeyboardButtonData("📊 System Info", "menu_info"),
		),
		tgbotapi.NewInlineKeyboardRow(
			tgbotapi.NewInlineKeyboardButtonData(modeLabel, "toggle_mode"),
		),
	)
}

func showPricing(bot *tgbotapi.BotAPI, chatID int64, config *BotConfig) {
	pricingMsg := fmt.Sprintf(
		"┌─────────────────────────────────┐\n"+
			"│         💎 **PRICING PLAN**       │\n"+
			"├─────────────────────────────────┤\n"+
			"│ 📅 *Daily*    : Rp %s/hari\n"+
			"│ 📆 *Weekly*   : Rp %s (7 days)\n"+
			"│ 📅 *Monthly*  : Rp %s (30 days)\n"+
			"│ 🎁 *Trial*    : %d Days FREE!\n"+
			"├─────────────────────────────────┤\n"+
			"│  💳 *Payment: QRIS (All Banks)*  │\n"+
			"│  ⚡ *Auto activation after payment│\n"+
			"└─────────────────────────────────┘\n\n"+
			"💡 *Tips:* Buy weekly or monthly for better value!",
		formatRupiah(config.DailyPrice),
		formatRupiah(config.DailyPrice*7),
		formatRupiah(config.DailyPrice*30),
		TrialDuration)

	keyboard := tgbotapi.NewInlineKeyboardMarkup(
		tgbotapi.NewInlineKeyboardRow(
			tgbotapi.NewInlineKeyboardButtonData("🛒 Buy Now", "menu_create"),
			tgbotapi.NewInlineKeyboardButtonData("🎁 Try Free", "menu_trial"),
		),
		tgbotapi.NewInlineKeyboardRow(
			tgbotapi.NewInlineKeyboardButtonData("◀️ Back to Menu", "back_menu"),
		),
	)

	sendModernMessage(bot, chatID, pricingMsg, &keyboard)
}

func sendModernMessage(bot *tgbotapi.BotAPI, chatID int64, text string, keyboard *tgbotapi.InlineKeyboardMarkup) {
	msg := tgbotapi.NewMessage(chatID, text)
	msg.ParseMode = "Markdown"

	if keyboard != nil {
		msg.ReplyMarkup = keyboard
	} else if _, inState := userStates[chatID]; inState {
		cancelKb := tgbotapi.NewInlineKeyboardMarkup(
			tgbotapi.NewInlineKeyboardRow(tgbotapi.NewInlineKeyboardButtonData("❌ Cancel", "cancel")),
		)
		msg.ReplyMarkup = cancelKb
	}

	sendAndTrack(bot, msg)
}

// ==========================================
// Trial Feature Implementation
// ==========================================

func handleTrialRequest(bot *tgbotapi.BotAPI, chatID int64, userID int64, config *BotConfig) {
	// Check if user already claimed trial
	if trialUsers[userID] {
		sendModernMessage(bot, chatID,
			"❌ **Trial Limit Reached**\n\n"+
				"You have already claimed your free trial!\n"+
				"🎉 *Upgrade to Premium for unlimited access* 🎉",
			nil)
		return
	}

	// Start trial account creation
	tempUserData[userID] = make(map[string]string)
	tempUserData[userID]["is_trial"] = "true"
	userStates[userID] = "trial_username"

	sendModernMessage(bot, chatID,
		"🎁 **FREE TRIAL ACCOUNT**\n\n"+
			"✨ *1 Days Free Trial with 1 Device Limit*\n\n"+
			"📝 **Create your username:**\n"+
			"• 3-20 characters\n"+
			"• Letters, numbers, - and _ only\n"+
			"• Choose wisely, this cannot be changed!",
		nil)
}

func createTrialAccount(bot *tgbotapi.BotAPI, chatID int64, userID int64, config *BotConfig) {
	username := tempUserData[userID]["username"]

	// Create trial account
	res, err := apiCall("POST", "/user/create", map[string]interface{}{
		"password": username,
		"days":     TrialDuration,
		"ip_limit": TrialLimit,
	})

	if err != nil {
		replyError(bot, chatID, "❌ Failed to create trial account: "+err.Error())
		resetState(userID)
		return
	}

	if res["success"] == true {
		data := res["data"].(map[string]interface{})
		trialUsers[userID] = true
		sendTrialAccountInfo(bot, chatID, data, config)
		delete(tempUserData, userID)
		resetState(userID)
	} else {
		replyError(bot, chatID, fmt.Sprintf("❌ Failed: %s", res["message"]))
		resetState(userID)
	}
}

func sendTrialAccountInfo(bot *tgbotapi.BotAPI, chatID int64, data map[string]interface{}, config *BotConfig) {
	ipInfo, _ := getIpInfo()
	domain := config.Domain
	if domain == "" {
		domain = "Premium Service"
	}

	accountMsg := fmt.Sprintf(
		"┌─────────────────────────────────┐\n"+
			"│     🎁 **TRIAL ACCOUNT** 🎁       │\n"+
			"├─────────────────────────────────┤\n"+
			"│ 🔑 *Username*  : `%s`\n"+
			"│ 🔒 *Password*  : `%s`\n"+
			"│ 📱 *Limit IP*  : %d Device\n"+
			"│ 📍 *Location*  : %s\n"+
			"│ 🔌 *ISP*       : %s\n"+
			"│ 🌐 *Domain*    : %s\n"+
			"│ ⏰ *Expired*   : %s\n"+
			"├─────────────────────────────────┤\n"+
			"│  ✨ *Upgrade to Premium Now!* ✨  │\n"+
			"│  🚀 Unlimited access & more IPs  │\n"+
			"└─────────────────────────────────┘",
		data["password"], data["password"], TrialLimit,
		ipInfo.City, ipInfo.Isp, domain, data["expired"])

	keyboard := tgbotapi.NewInlineKeyboardMarkup(
		tgbotapi.NewInlineKeyboardRow(
			tgbotapi.NewInlineKeyboardButtonData("🛒 Upgrade to Premium", "menu_create"),
		),
		tgbotapi.NewInlineKeyboardRow(
			tgbotapi.NewInlineKeyboardButtonData("◀️ Back to Menu", "back_menu"),
		),
	)

	msg := tgbotapi.NewMessage(chatID, accountMsg)
	msg.ParseMode = "Markdown"
	msg.ReplyMarkup = keyboard
	deleteLastMessage(bot, chatID)
	bot.Send(msg)
}

// ==========================================
// Feature Implementation (Enhanced)
// ==========================================

func startCreateUser(bot *tgbotapi.BotAPI, chatID int64, userID int64) {
	userStates[userID] = "create_username"
	tempUserData[userID] = make(map[string]string)
	sendModernMessage(bot, chatID,
		"🛒 **Create Premium Account**\n\n"+
			"📝 **Enter your username:**\n"+
			"• 3-20 characters\n"+
			"• Letters, numbers, - and _ only\n"+
			"• This will be your VPN login", nil)
}

func startRenewUser(bot *tgbotapi.BotAPI, chatID int64, userID int64, data string) {
	username := strings.TrimPrefix(data, "select_renew:")
	tempUserData[userID] = map[string]string{"username": username}
	userStates[userID] = "renew_days"
	sendModernMessage(bot, chatID,
		fmt.Sprintf("🔄 **Renew Account**\n\n👤 Username: `%s`\n\n⏳ **Enter additional duration (days):**\nMin: 1 day - Max: 365 days", username), nil)
}

func confirmDeleteUser(bot *tgbotapi.BotAPI, chatID int64, data string) {
	username := strings.TrimPrefix(data, "select_delete:")
	msg := tgbotapi.NewMessage(chatID, fmt.Sprintf("❓ Yakin ingin menghapus user `%s`?", username))
	msg.ParseMode = "Markdown"
	msg.ReplyMarkup = tgbotapi.NewInlineKeyboardMarkup(
		tgbotapi.NewInlineKeyboardRow(
			tgbotapi.NewInlineKeyboardButtonData("✅ Ya, Hapus", "confirm_delete:"+username),
			tgbotapi.NewInlineKeyboardButtonData("❌ Batal", "cancel"),
		),
	)
	sendAndTrack(bot, msg)
}

func cancelOperation(bot *tgbotapi.BotAPI, chatID int64, userID int64, config *BotConfig) {
	resetState(userID)
	showMainMenu(bot, chatID, config)
}

func handlePagination(bot *tgbotapi.BotAPI, chatID int64, data string) {
	parts := strings.Split(data, ":")
	action := parts[0][5:] // remove "page_"
	page, _ := strconv.Atoi(parts[1])
	showUserSelection(bot, chatID, page, action)
}

func toggleMode(bot *tgbotapi.BotAPI, chatID int64, userID int64, config *BotConfig) {
	if userID != config.AdminID {
		return
	}
	if config.Mode == "public" {
		config.Mode = "private"
	} else {
		config.Mode = "public"
	}
	saveConfig(config)
	showMainMenu(bot, chatID, config)
}

func createUser(bot *tgbotapi.BotAPI, chatID int64, username string, days int, limit int, config *BotConfig) {
	res, err := apiCall("POST", "/user/create", map[string]interface{}{
		"password": username,
		"days":     days,
		"ip_limit": limit,
	})

	if err != nil {
		replyError(bot, chatID, "❌ API Error: "+err.Error())
		return
	}

	if res["success"] == true {
		data := res["data"].(map[string]interface{})
		sendAccountInfo(bot, chatID, data, limit, config)
	} else {
		replyError(bot, chatID, fmt.Sprintf("❌ Gagal: %s", res["message"]))
		showMainMenu(bot, chatID, config)
	}
}

func renewUser(bot *tgbotapi.BotAPI, chatID int64, username string, days int, config *BotConfig) {
	res, err := apiCall("POST", "/user/renew", map[string]interface{}{
		"password": username,
		"days":     days,
	})

	if err != nil {
		replyError(bot, chatID, "❌ API Error: "+err.Error())
		return
	}

	if res["success"] == true {
		data := res["data"].(map[string]interface{})
		sendAccountInfo(bot, chatID, data, 0, config)
	} else {
		replyError(bot, chatID, fmt.Sprintf("❌ Gagal: %s", res["message"]))
		showMainMenu(bot, chatID, config)
	}
}

func deleteUser(bot *tgbotapi.BotAPI, chatID int64, username string, config *BotConfig) {
	res, err := apiCall("POST", "/user/delete", map[string]interface{}{
		"password": username,
	})

	if err != nil {
		replyError(bot, chatID, "❌ API Error: "+err.Error())
		return
	}

	if res["success"] == true {
		msg := tgbotapi.NewMessage(chatID, "✅ Password berhasil dihapus.")
		deleteLastMessage(bot, chatID)
		bot.Send(msg)
		showMainMenu(bot, chatID, config)
	} else {
		replyError(bot, chatID, fmt.Sprintf("❌ Gagal: %s", res["message"]))
		showMainMenu(bot, chatID, config)
	}
}

func listUsers(bot *tgbotapi.BotAPI, chatID int64) {
	res, err := apiCall("GET", "/users", nil)
	if err != nil {
		replyError(bot, chatID, "❌ API Error: "+err.Error())
		return
	}

	if res["success"] == true {
		users := res["data"].([]interface{})
		if len(users) == 0 {
			sendModernMessage(bot, chatID, "📂 Tidak ada user.", nil)
			return
		}

		msg := "┌─────────────────────────────────┐\n" +
			"│       📋 **ACCOUNT LIST**          │\n" +
			"├─────────────────────────────────┤\n"

		for _, u := range users {
			user := u.(map[string]interface{})
			status := "🟢"
			if user["status"] == "Expired" {
				status = "🔴"
			}
			msg += fmt.Sprintf("│ %s `%s` → %s\n", status, user["password"], user["expired"])
		}
		msg += "└─────────────────────────────────┘"

		reply := tgbotapi.NewMessage(chatID, msg)
		reply.ParseMode = "Markdown"
		sendAndTrack(bot, reply)
	} else {
		replyError(bot, chatID, "❌ Gagal mengambil data.")
	}
}

func systemInfo(bot *tgbotapi.BotAPI, chatID int64, config *BotConfig) {
	res, err := apiCall("GET", "/info", nil)
	if err != nil {
		replyError(bot, chatID, "❌ API Error: "+err.Error())
		return
	}

	if res["success"] == true {
		data := res["data"].(map[string]interface{})
		ipInfo, _ := getIpInfo()

		infoMsg := fmt.Sprintf(
			"┌─────────────────────────────────┐\n"+
				"│       📊 **SYSTEM INFORMATION**    │\n"+
				"├─────────────────────────────────┤\n"+
				"│ 🌐 *Domain*    : %s\n"+
				"│ 📍 *Location*  : %s\n"+
				"│ 🔌 *ISP*       : %s\n"+
				"│ 🚪 *Port*      : %s\n"+
				"│ ⚙️ *Service*   : %s\n"+
				"├─────────────────────────────────┤\n"+
				"│  ✅ *System is operational*       │\n"+
				"└─────────────────────────────────┘",
			config.Domain, ipInfo.City, ipInfo.Isp, data["port"], data["service"])

		reply := tgbotapi.NewMessage(chatID, infoMsg)
		reply.ParseMode = "Markdown"
		deleteLastMessage(bot, chatID)
		bot.Send(reply)

		keyboard := tgbotapi.NewInlineKeyboardMarkup(
			tgbotapi.NewInlineKeyboardRow(
				tgbotapi.NewInlineKeyboardButtonData("◀️ Back to Menu", "back_menu"),
			),
		)
		msg := tgbotapi.NewMessage(chatID, "Choose an option:")
		msg.ReplyMarkup = keyboard
		sendAndTrack(bot, msg)
	} else {
		replyError(bot, chatID, "❌ Gagal mengambil info.")
	}
}

func sendAccountInfo(bot *tgbotapi.BotAPI, chatID int64, data map[string]interface{}, limit int, config *BotConfig) {
	ipInfo, _ := getIpInfo()
	domain := config.Domain
	if domain == "" {
		domain = "Premium Service"
	}

	limitStr := ""
	if limit > 0 {
		limitStr = fmt.Sprintf("\n│ 📱 *Limit IP*  : %d Device", limit)
	}

	msg := fmt.Sprintf("┌─────────────────────────────────┐\n"+
		"│      ✨ **PREMIUM ACCOUNT** ✨     │\n"+
		"├─────────────────────────────────┤\n"+
		"│ 🔑 *Username*  : `%s`\n"+
		"│ 🔒 *Password*  : `%s`%s\n"+
		"│ 📍 *Location*  : %s\n"+
		"│ 🔌 *ISP*       : %s\n"+
		"│ 🌐 *Domain*    : %s\n"+
		"│ ⏰ *Expired*   : %s\n"+
		"├─────────────────────────────────┤\n"+
		"│  🎉 *Thank you for subscribing!* │\n"+
		"│  🚀 *Enjoy high-speed connection* │\n"+
		"└─────────────────────────────────┘",
		data["password"], data["password"], limitStr,
		ipInfo.City, ipInfo.Isp, domain, data["expired"])

	reply := tgbotapi.NewMessage(chatID, msg)
	reply.ParseMode = "Markdown"
	deleteLastMessage(bot, chatID)
	bot.Send(reply)
	showMainMenu(bot, chatID, config)
}

func showUserSelection(bot *tgbotapi.BotAPI, chatID int64, page int, action string) {
	users, err := getUsers()
	if err != nil {
		replyError(bot, chatID, "❌ Gagal mengambil data user.")
		return
	}

	if len(users) == 0 {
		sendModernMessage(bot, chatID, "📂 Tidak ada user.", nil)
		return
	}

	perPage := 10
	totalPages := (len(users) + perPage - 1) / perPage

	if page < 1 {
		page = 1
	}
	if page > totalPages {
		page = totalPages
	}

	start := (page - 1) * perPage
	end := start + perPage
	if end > len(users) {
		end = len(users)
	}

	var rows [][]tgbotapi.InlineKeyboardButton
	for _, u := range users[start:end] {
		label := fmt.Sprintf("%s (%s)", u.Password, u.Status)
		if u.Status == "Expired" {
			label = fmt.Sprintf("🔴 %s", label)
		} else {
			label = fmt.Sprintf("🟢 %s", label)
		}
		data := fmt.Sprintf("select_%s:%s", action, u.Password)
		rows = append(rows, tgbotapi.NewInlineKeyboardRow(
			tgbotapi.NewInlineKeyboardButtonData(label, data),
		))
	}

	var navRow []tgbotapi.InlineKeyboardButton
	if page > 1 {
		navRow = append(navRow, tgbotapi.NewInlineKeyboardButtonData("⬅️ Prev", fmt.Sprintf("page_%s:%d", action, page-1)))
	}
	if page < totalPages {
		navRow = append(navRow, tgbotapi.NewInlineKeyboardButtonData("Next ➡️", fmt.Sprintf("page_%s:%d", action, page+1)))
	}
	if len(navRow) > 0 {
		rows = append(rows, navRow)
	}

	rows = append(rows, tgbotapi.NewInlineKeyboardRow(tgbotapi.NewInlineKeyboardButtonData("❌ Batal", "cancel")))

	msg := tgbotapi.NewMessage(chatID, fmt.Sprintf("📋 Pilih User untuk %s (Halaman %d/%d):", strings.Title(action), page, totalPages))
	msg.ReplyMarkup = tgbotapi.NewInlineKeyboardMarkup(rows...)
	sendAndTrack(bot, msg)
}

// ==========================================
// Helper Functions
// ==========================================

func formatRupiah(amount int) string {
	amountStr := strconv.Itoa(amount)
	n := len(amountStr)
	if n <= 3 {
		return amountStr
	}

	var result strings.Builder
	for i, digit := range amountStr {
		if i > 0 && (n-i)%3 == 0 {
			result.WriteRune('.')
		}
		result.WriteRune(digit)
	}
	return result.String()
}

func sendMessage(bot *tgbotapi.BotAPI, chatID int64, text string) {
	sendModernMessage(bot, chatID, text, nil)
}

func replyError(bot *tgbotapi.BotAPI, chatID int64, text string) {
	sendModernMessage(bot, chatID, text, nil)
}

func sendAndTrack(bot *tgbotapi.BotAPI, msg tgbotapi.MessageConfig) {
	deleteLastMessage(bot, msg.ChatID)
	sentMsg, err := bot.Send(msg)
	if err == nil {
		lastMessageIDs[msg.ChatID] = sentMsg.MessageID
	}
}

func deleteLastMessage(bot *tgbotapi.BotAPI, chatID int64) {
	if msgID, ok := lastMessageIDs[chatID]; ok {
		deleteMsg := tgbotapi.NewDeleteMessage(chatID, msgID)
		bot.Request(deleteMsg)
		delete(lastMessageIDs, chatID)
	}
}

func resetState(userID int64) {
	delete(userStates, userID)
	delete(tempUserData, userID)
}

// ==========================================
// Validation Helpers
// ==========================================

func validateUsername(bot *tgbotapi.BotAPI, chatID int64, text string) bool {
	if len(text) < 3 || len(text) > 20 {
		sendModernMessage(bot, chatID, "❌ **Invalid Username**\n\nUsername must be 3-20 characters.\nPlease try again:", nil)
		return false
	}
	if !regexp.MustCompile(`^[a-zA-Z0-9_-]+$`).MatchString(text) {
		sendModernMessage(bot, chatID, "❌ **Invalid Username**\n\nOnly letters, numbers, - and _ allowed.\nPlease try again:", nil)
		return false
	}
	return true
}

func validateNumber(bot *tgbotapi.BotAPI, chatID int64, text string, min, max int, fieldName string) (int, bool) {
	val, err := strconv.Atoi(text)
	if err != nil || val < min || val > max {
		sendModernMessage(bot, chatID, fmt.Sprintf("❌ **Invalid %s**\n\nPlease enter a number between %d-%d.\nTry again:", fieldName, min, max), nil)
		return 0, false
	}
	return val, true
}

// ==========================================
// Configuration & Utils
// ==========================================

func isAllowed(config *BotConfig, userID int64) bool {
	return config.Mode == "public" || userID == config.AdminID
}

func saveConfig(config *BotConfig) error {
	data, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
	}
	return ioutil.WriteFile(BotConfigFile, data, 0644)
}

func loadConfig() (BotConfig, error) {
	var config BotConfig
	file, err := ioutil.ReadFile(BotConfigFile)
	if err != nil {
		return config, err
	}
	err = json.Unmarshal(file, &config)

	// Jika domain kosong di config, coba baca dari file domain
	if config.Domain == "" {
		if domainBytes, err := ioutil.ReadFile(DomainFile); err == nil {
			config.Domain = strings.TrimSpace(string(domainBytes))
		}
	}

	// Set default daily price if not set
	if config.DailyPrice == 0 {
		config.DailyPrice = 1000 // Default price
	}

	return config, err
}

// ==========================================
// API Client
// ==========================================

func apiCall(method, endpoint string, payload interface{}) (map[string]interface{}, error) {
	var reqBody []byte
	var err error

	if payload != nil {
		reqBody, err = json.Marshal(payload)
		if err != nil {
			return nil, err
		}
	}

	client := &http.Client{}
	req, err := http.NewRequest(method, ApiUrl+endpoint, bytes.NewBuffer(reqBody))
	if err != nil {
		return nil, err
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-API-Key", ApiKey)

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, _ := ioutil.ReadAll(resp.Body)
	var result map[string]interface{}
	json.Unmarshal(body, &result)

	return result, nil
}

func getIpInfo() (IpInfo, error) {
	resp, err := http.Get("http://ip-api.com/json/")
	if err != nil {
		return IpInfo{}, err
	}
	defer resp.Body.Close()

	var info IpInfo
	if err := json.NewDecoder(resp.Body).Decode(&info); err != nil {
		return IpInfo{}, err
	}
	return info, nil
}

func getUsers() ([]UserData, error) {
	res, err := apiCall("GET", "/users", nil)
	if err != nil {
		return nil, err
	}

	if res["success"] != true {
		return nil, fmt.Errorf("failed to get users")
	}

	var users []UserData
	dataBytes, _ := json.Marshal(res["data"])
	json.Unmarshal(dataBytes, &users)
	return users, nil
}