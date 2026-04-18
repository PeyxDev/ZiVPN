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
	AdminID        int64  `json:"admin_id"`
	Mode           string `json:"mode"`
	Domain         string `json:"domain"`
	PakasirSlug    string `json:"pakasir_slug"`
	PakasirApiKey  string `json:"pakasir_api_key"`
	DailyPrice     int    `json:"daily_price"`
	DefaultIpLimit int    `json:"default_ip_limit"`
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
	if keyBytes, err := ioutil.ReadFile(ApiKeyFile); err == nil {
		ApiKey = strings.TrimSpace(string(keyBytes))
	}

	config, err := loadConfig()
	if err != nil {
		log.Fatal("Gagal memuat konfigurasi bot:", err)
	}

	bot, err := tgbotapi.NewBotAPI(config.BotToken)
	if err != nil {
		log.Panic(err)
	}

	bot.Debug = false
	log.Printf("Authorized on account %s", bot.Self.UserName)

	u := tgbotapi.NewUpdate(0)
	u.Timeout = 60
	updates := bot.GetUpdatesChan(u)

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
	if state, exists := userStates[msg.From.ID]; exists {
		handleState(bot, msg, state, config)
		return
	}

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
	chatID := query.Message.Chat.ID
	userID := query.From.ID

	switch {
	case query.Data == "menu_create":
		startCreateUser(bot, chatID, userID)
	case query.Data == "menu_trial":
		handleTrialRequest(bot, chatID, userID, config)
	case query.Data == "menu_info":
		systemInfo(bot, chatID, config)
	case query.Data == "menu_pricing":
		showPricing(bot, chatID, config)
	case query.Data == "cancel":
		cancelOperation(bot, chatID, userID, config)
	case strings.HasPrefix(query.Data, "check_payment:"):
		orderID := strings.TrimPrefix(query.Data, "check_payment:")
		checkPayment(bot, chatID, userID, orderID, query.ID, config)
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
		sendModernMessage(bot, chatID, "⏳ **Masukkan Durasi (Hari)**\n\nHarga: *Rp " + formatRupiah(config.DailyPrice) + "*/hari\nMinimal 1 hari - Maksimal 365 hari", nil)

	case "create_days":
		days, ok := validateNumber(bot, chatID, text, 1, 365, "Durasi")
		if !ok {
			return
		}
		tempUserData[userID]["days"] = text
		processPayment(bot, chatID, userID, days, config)
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

	// Modern welcome message with emojis and formatting
	welcomeMsg := fmt.Sprintf(
		"┌─────────────────────────────────┐\n"+
		"│      🚀 **ZIVPN PREMIUM** 🚀      │\n"+
		"├─────────────────────────────────┤\n"+
		"│ 🌐 *Domain*   : %s\n"+
		"│ 📍 *City*     : %s\n"+
		"│ 🔌 *ISP*      : %s\n"+
		"│ 💰 *Price*    : Rp %s/hari\n"+
		"├─────────────────────────────────┤\n"+
		"│   🎯 *Fast • Stable • Secure*    │\n"+
		"└─────────────────────────────────┘\n\n"+
		"✨ *Experience the best VPN service!* ✨",
		domain, ipInfo.City, ipInfo.Isp, formatRupiah(config.DailyPrice))

	// Modern keyboard layout
	keyboard := tgbotapi.NewInlineKeyboardMarkup(
		tgbotapi.NewInlineKeyboardRow(
			tgbotapi.NewInlineKeyboardButtonData("🛒 **BUY PREMIUM**", "menu_create"),
			tgbotapi.NewInlineKeyboardButtonData("🎁 **FREE TRIAL**", "menu_trial"),
		),
		tgbotapi.NewInlineKeyboardRow(
			tgbotapi.NewInlineKeyboardButtonData("📊 **SYSTEM INFO**", "menu_info"),
			tgbotapi.NewInlineKeyboardButtonData("💰 **PRICING**", "menu_pricing"),
		),
	)

	msg := tgbotapi.NewMessage(chatID, welcomeMsg)
	msg.ParseMode = "Markdown"
	msg.ReplyMarkup = keyboard
	sendAndTrack(bot, msg)
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
		"└─────────────────────────────────┘",
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
		sendModernMessage(bot, chatID, 
			fmt.Sprintf("⏳ **Enter Duration (Days)**\n\n💰 Price: *Rp %s/day*\n📅 Min: 1 day - Max: 365 days", 
			formatRupiah(config.DailyPrice)), nil)

	case "create_days":
		days, ok := validateNumber(bot, chatID, text, 1, 365, "Duration")
		if !ok {
			return
		}
		tempUserData[userID]["days"] = text
		processPayment(bot, chatID, userID, days, config)

	case "trial_username":
		if !validateUsername(bot, chatID, text) {
			return
		}
		tempUserData[userID]["username"] = text
		createTrialAccount(bot, chatID, userID, config)
	}
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
	)

	msg := tgbotapi.NewMessage(chatID, accountMsg)
	msg.ParseMode = "Markdown"
	msg.ReplyMarkup = keyboard
	deleteLastMessage(bot, chatID)
	bot.Send(msg)
}

// ==========================================
// Payment Processing (Updated with Modern UI)
// ==========================================

func processPayment(bot *tgbotapi.BotAPI, chatID int64, userID int64, days int, config *BotConfig) {
	price := days * config.DailyPrice
	if price < 267 {
		sendModernMessage(bot, chatID, 
			fmt.Sprintf("❌ **Minimum Transaction Required**\n\nTotal: *Rp %s*\nMinimum: *Rp 267*\n\n📅 Please add more days to continue.", 
			formatRupiah(price)), nil)
		return
	}
	
	orderID := fmt.Sprintf("ZIVPN-%d-%d", userID, time.Now().Unix())

	// Call Pakasir API
	payment, err := createPakasirTransaction(config, orderID, price)
	if err != nil {
		replyError(bot, chatID, "❌ Payment creation failed: "+err.Error())
		resetState(userID)
		return
	}

	// Store Order ID for verification
	tempUserData[userID]["order_id"] = orderID
	tempUserData[userID]["price"] = strconv.Itoa(price)

	// Generate QR Image URL
	qrUrl := fmt.Sprintf("https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=%s", payment.PaymentNumber)

	paymentMsg := fmt.Sprintf(
		"┌─────────────────────────────────┐\n"+
		"│       💳 **PAYMENT INVOICE**      │\n"+
		"├─────────────────────────────────┤\n"+
		"│ 👤 *Username* : `%s`\n"+
		"│ 📅 *Duration* : %d Days\n"+
		"│ 💰 *Total*    : Rp %s\n"+
		"│ ⏰ *Expired*  : %s\n"+
		"├─────────────────────────────────┤\n"+
		"│  📱 *Scan QRIS above to pay*     │\n"+
		"│  ✅ *Auto activation after paid* │\n"+
		"└─────────────────────────────────┘",
		tempUserData[userID]["username"], days, formatRupiah(price), payment.ExpiredAt)

	photo := tgbotapi.NewPhoto(chatID, tgbotapi.FileURL(qrUrl))
	photo.Caption = paymentMsg
	photo.ParseMode = "Markdown"

	keyboard := tgbotapi.NewInlineKeyboardMarkup(
		tgbotapi.NewInlineKeyboardRow(
			tgbotapi.NewInlineKeyboardButtonData("✅ Check Payment", "check_payment:"+orderID),
			tgbotapi.NewInlineKeyboardButtonData("❌ Cancel", "cancel"),
		),
	)
	photo.ReplyMarkup = keyboard

	deleteLastMessage(bot, chatID)
	sentMsg, err := bot.Send(photo)
	if err == nil {
		lastMessageIDs[chatID] = sentMsg.MessageID
	}

	// Clear state but keep tempUserData for verification
	delete(userStates, userID)
}

func sendAccountInfo(bot *tgbotapi.BotAPI, chatID int64, data map[string]interface{}, limit int, config *BotConfig) {
	ipInfo, _ := getIpInfo()
	domain := config.Domain
	if domain == "" {
		domain = "Premium Service"
	}

	accountMsg := fmt.Sprintf(
		"┌─────────────────────────────────┐\n"+
		"│      ✨ **PREMIUM ACCOUNT** ✨     │\n"+
		"├─────────────────────────────────┤\n"+
		"│ 🔑 *Username*  : `%s`\n"+
		"│ 🔒 *Password*  : `%s`\n"+
		"│ 📱 *Limit IP*  : %d Device\n"+
		"│ 📍 *Location*  : %s\n"+
		"│ 🔌 *ISP*       : %s\n"+
		"│ 🌐 *Domain*    : %s\n"+
		"│ ⏰ *Expired*   : %s\n"+
		"├─────────────────────────────────┤\n"+
		"│  🎉 *Thank you for subscribing!* │\n"+
		"│  🚀 *Enjoy high-speed connection* │\n"+
		"└─────────────────────────────────┘",
		data["password"], data["password"], limit, 
		ipInfo.City, ipInfo.Isp, domain, data["expired"])

	reply := tgbotapi.NewMessage(chatID, accountMsg)
	reply.ParseMode = "Markdown"
	deleteLastMessage(bot, chatID)
	bot.Send(reply)
	showMainMenu(bot, chatID, config)
}

// ==========================================
// Helper Functions
// ==========================================

func formatRupiah(amount int) string {
	amountStr := strconv.Itoa(amount)
	// Add thousand separators
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
		sendModernMessage(bot, chatID, 
			fmt.Sprintf("❌ **Invalid %s**\n\nPlease enter a number between %d-%d.\nTry again:", fieldName, min, max), nil)
		return 0, false
	}
	return val, true
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
		replyError(bot, chatID, "❌ Failed to fetch system info.")
	}
}

// ==========================================
// Pakasir API (Unchanged)
// ==========================================

type PakasirPayment struct {
	PaymentNumber string `json:"payment_number"`
	ExpiredAt     string `json:"expired_at"`
}

func createPakasirTransaction(config *BotConfig, orderID string, amount int) (*PakasirPayment, error) {
	url := fmt.Sprintf("https://app.pakasir.com/api/transactioncreate/qris")
	payload := map[string]interface{}{
		"project":  config.PakasirSlug,
		"order_id": orderID,
		"amount":   amount,
		"api_key":  config.PakasirApiKey,
	}

	jsonPayload, _ := json.Marshal(payload)
	req, _ := http.NewRequest("POST", url, bytes.NewBuffer(jsonPayload))
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&result)

	if paymentData, ok := result["payment"].(map[string]interface{}); ok {
		return &PakasirPayment{
			PaymentNumber: paymentData["payment_number"].(string),
			ExpiredAt:     paymentData["expired_at"].(string),
		}, nil
	}
	return nil, fmt.Errorf("invalid response from Pakasir")
}

func checkPakasirStatus(config *BotConfig, orderID string, amountStr string) (string, error) {
	url := fmt.Sprintf("https://app.pakasir.com/api/transactiondetail?project=%s&amount=%s&order_id=%s&api_key=%s",
		config.PakasirSlug, amountStr, orderID, config.PakasirApiKey)

	resp, err := http.Get(url)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	var result map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&result)

	if transaction, ok := result["transaction"].(map[string]interface{}); ok {
		return transaction["status"].(string), nil
	}
	return "", fmt.Errorf("transaction not found")
}

// ==========================================
// Other Helper Functions
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

func checkPayment(bot *tgbotapi.BotAPI, chatID int64, userID int64, orderID string, queryID string, config *BotConfig) {
	if tempUserData[userID]["order_id"] != orderID {
		replyError(bot, chatID, "❌ Transaction data not found. Please start over.")
		return
	}

	status, err := checkPakasirStatus(config, orderID, tempUserData[userID]["price"])
	if err != nil {
		bot.Request(tgbotapi.NewCallback(queryID, "Error: "+err.Error()))
		return
	}

	if status == "completed" || status == "success" {
		// Payment Success -> Create Account
		username := tempUserData[userID]["username"]
		days, _ := strconv.Atoi(tempUserData[userID]["days"])
		limit := config.DefaultIpLimit
		if limit < 1 {
			limit = 1
		}

		createUser(bot, chatID, username, days, limit, config)
		delete(tempUserData, userID)
		bot.Request(tgbotapi.NewCallback(queryID, "✅ Payment confirmed! Creating account..."))
	} else {
		bot.Request(tgbotapi.NewCallback(queryID, "⏳ Payment pending / "+status))
	}
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
		replyError(bot, chatID, fmt.Sprintf("❌ Failed to create account: %s", res["message"]))
	}
}

func cancelOperation(bot *tgbotapi.BotAPI, chatID int64, userID int64, config *BotConfig) {
	resetState(userID)
	sendModernMessage(bot, chatID, "❌ Operation cancelled.", nil)
	showMainMenu(bot, chatID, config)
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
}

func loadConfig() (BotConfig, error) {
	var config BotConfig
	file, err := ioutil.ReadFile(BotConfigFile)
	if err != nil {
		return config, err
	}
	err = json.Unmarshal(file, &config)

	if config.Domain == "" {
		if domainBytes, err := ioutil.ReadFile(DomainFile); err == nil {
			config.Domain = strings.TrimSpace(string(domainBytes))
		}
	}

	return config, err
}

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