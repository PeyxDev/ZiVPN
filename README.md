<!DOCTYPE html>

<html class="dark" lang="en"><head>
<meta charset="utf-8"/>
<meta content="width=device-width, initial-scale=1.0" name="viewport"/>
<title>ZiVPN | Kinetic Ether UDP Tunneling</title>
<script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
<link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@300;400;500;600;700&amp;family=Inter:wght@300;400;500;600;700&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<script id="tailwind-config">
        tailwind.config = {
            darkMode: "class",
            theme: {
                extend: {
                    "colors": {
                        "tertiary-fixed-dim": "#d1bcff",
                        "error": "#ffb4ab",
                        "on-secondary-fixed": "#000767",
                        "surface-dim": "#10141a",
                        "on-primary": "#00363a",
                        "on-error": "#690005",
                        "surface-container-lowest": "#0a0e14",
                        "on-tertiary-container": "#7213ff",
                        "inverse-surface": "#dfe2eb",
                        "surface-container": "#1c2026",
                        "surface-container-highest": "#31353c",
                        "secondary-container": "#343d96",
                        "on-primary-container": "#006970",
                        "secondary": "#bdc2ff",
                        "tertiary-container": "#e1d2ff",
                        "surface": "#10141a",
                        "on-tertiary": "#3c0090",
                        "primary": "#dbfcff",
                        "inverse-on-surface": "#2d3137",
                        "on-surface-variant": "#b9cacb",
                        "background": "#10141a",
                        "outline-variant": "#3b494b",
                        "on-secondary-fixed-variant": "#343d96",
                        "surface-tint": "#00dbe9",
                        "tertiary": "#faf3ff",
                        "on-secondary": "#1b247f",
                        "outline": "#849495",
                        "surface-bright": "#353940",
                        "primary-fixed-dim": "#00dbe9",
                        "primary-container": "#00f0ff",
                        "surface-container-high": "#262a31",
                        "on-primary-fixed-variant": "#004f54",
                        "secondary-fixed-dim": "#bdc2ff",
                        "error-container": "#93000a",
                        "primary-fixed": "#7df4ff",
                        "on-error-container": "#ffdad6",
                        "on-tertiary-fixed-variant": "#5700c9",
                        "on-surface": "#dfe2eb",
                        "on-tertiary-fixed": "#23005b",
                        "surface-container-low": "#181c22",
                        "on-background": "#dfe2eb",
                        "surface-variant": "#31353c",
                        "tertiary-fixed": "#e9ddff",
                        "on-primary-fixed": "#002022",
                        "on-secondary-container": "#a8afff",
                        "secondary-fixed": "#e0e0ff",
                        "inverse-primary": "#006970"
                    },
                    "borderRadius": {
                        "DEFAULT": "0.125rem",
                        "lg": "0.25rem",
                        "xl": "0.5rem",
                        "full": "0.75rem"
                    },
                    "fontFamily": {
                        "headline": ["Space Grotesk"],
                        "body": ["Inter"],
                        "label": ["Space Grotesk"]
                    }
                }
            }
        }
    </script>
<style>
        .material-symbols-outlined {
            font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24;
        }
        .glow-text {
            text-shadow: 0 0 20px rgba(0, 240, 255, 0.4);
        }
        .glass-panel {
            background: rgba(49, 53, 60, 0.4);
            backdrop-filter: blur(12px);
        }
        .no-scrollbar::-webkit-scrollbar {
            display: none;
        }
    </style>
<style>
    body {
      min-height: max(884px, 100dvh);
    }
  </style>
  </head>
<body class="bg-background text-on-background font-body selection:bg-primary-container selection:text-on-primary">
<!-- TopAppBar -->
<header class="bg-[#10141a]/80 backdrop-blur-xl fixed top-0 w-full z-50 shadow-[0_24px_24px_0_rgba(10,14,20,0.06)]">
<div class="max-w-7xl mx-auto flex items-center justify-between px-6 py-4">
<div class="flex items-center gap-3">
<span class="material-symbols-outlined text-[#00f0ff] text-2xl" data-icon="shield">shield</span>
<h1 class="text-2xl font-bold tracking-tighter text-[#dbfcff] uppercase font-['Space_Grotesk']">ZiVPN</h1>
</div>
<button class="bg-primary-container text-on-primary px-4 py-2 rounded-md font-label text-sm font-bold tracking-tight active:scale-95 transition-transform">
                DOWNLOAD
            </button>
</div>
</header>
<main class="pt-24 pb-12">
<!-- Hero Section -->
<section class="px-6 py-12 relative overflow-hidden">
<div class="absolute inset-0 z-0 opacity-20">
<img alt="Network Hub" class="w-full h-full object-cover" data-alt="abstract digital network connections with glowing cyan lines and data points on a deep navy background high tech futuristic aesthetic" src="https://lh3.googleusercontent.com/aida-public/AB6AXuCkrTTAbmMC6gwVPAHarE_f2memeFW_Fhul_v48x7RZ55ieoYcxwSTi9uIHTRalyiYeeC5Z40JQfqSvRToWcfrxUn33U-2bmlJ9gZXOMYarrnZv5V-5X409D4m4ncmroNJ9ffBa8AqxPmVZc8LYlGr9rEJKWgRYmyHDy-WfP49zabX3thaDof4tUHjZcgTU_jKMzYGjkN2F4G5py20bWaRSmPxaPpXQenzOm4XGvgKaTm98XJTiCaKIus9okSz60Zx47HdaT90E6UHF"/>
</div>
<div class="relative z-10">
<div class="flex flex-wrap gap-2 mb-6">
<span class="bg-secondary-container text-on-secondary-container px-3 py-1 rounded-full text-[10px] font-label font-bold tracking-widest uppercase">v2.4.0-stable</span>
<span class="bg-surface-container-highest text-primary px-3 py-1 rounded-full text-[10px] font-label font-bold tracking-widest uppercase">UDP Tunnel</span>
</div>
<h2 class="text-5xl font-headline font-bold text-primary leading-tight glow-text mb-4">
                    ZiVPN UDP <br/><span class="text-primary-container">Kinetic Tunnel</span>
</h2>
<p class="text-on-surface-variant text-lg leading-relaxed max-w-md mb-8">
                    High-velocity data transmission with subterranean stability. Deploy modern UDP tunneling with headless management and automated QRIS payments.
                </p>
<div class="flex flex-col gap-4">
<div class="bg-surface-container-low p-4 rounded-lg flex items-center gap-4 group">
<div class="bg-primary-container/10 p-3 rounded text-primary-container">
<span class="material-symbols-outlined" data-icon="terminal">terminal</span>
</div>
<div class="overflow-hidden">
<p class="text-[10px] font-label text-outline mb-1 uppercase tracking-tighter">One-Line Install</p>
<code class="text-primary text-sm font-mono truncate">apt install zivpn -y &amp;&amp; zivpn init</code>
</div>
</div>
</div>
</div>
</section>
<!-- Key Features Bento Grid -->
<section class="px-6 py-16 space-y-4">
<div class="grid grid-cols-1 gap-4">
<!-- Feature 1 -->
<div class="bg-surface-container-low p-6 rounded-lg relative overflow-hidden group">
<div class="absolute top-0 right-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
<span class="material-symbols-outlined text-6xl" data-icon="bolt">bolt</span>
</div>
<span class="material-symbols-outlined text-primary-container mb-4 block" data-icon="rocket_launch">rocket_launch</span>
<h3 class="text-xl font-headline font-bold text-primary mb-2">Instalasi Modern</h3>
<p class="text-on-surface-variant text-sm leading-relaxed">Automated deployment environment designed for high-performance VPS nodes.</p>
</div>
<div class="grid grid-cols-2 gap-4">
<!-- Feature 2 -->
<div class="bg-surface-container-high p-6 rounded-lg">
<span class="material-symbols-outlined text-secondary mb-4 block" data-icon="memory">memory</span>
<h3 class="text-lg font-headline font-bold text-primary mb-2 leading-tight">Headless Control</h3>
<p class="text-on-surface-variant text-xs">Full CLI control for server administrators.</p>
</div>
<!-- Feature 3 -->
<div class="bg-surface-container-high p-6 rounded-lg border-t-2 border-primary-container/30">
<span class="material-symbols-outlined text-primary-container mb-4 block" data-icon="smart_toy">smart_toy</span>
<h3 class="text-lg font-headline font-bold text-primary mb-2 leading-tight">Bot Integrated</h3>
<p class="text-on-surface-variant text-xs">Manage accounts and payments via Telegram.</p>
</div>
</div>
</div>
</section>
<!-- Payment Flow -->
<section class="bg-surface-container-lowest px-6 py-16">
<h2 class="text-3xl font-headline font-bold text-primary mb-8 flex items-center gap-3">
<span class="material-symbols-outlined text-primary-container" data-icon="account_balance_wallet">account_balance_wallet</span>
                Payment Flow
            </h2>
<div class="space-y-12 relative">
<!-- Line -->
<div class="absolute left-4 top-2 bottom-2 w-px bg-outline-variant/30"></div>
<!-- Step 1 -->
<div class="relative pl-12">
<div class="absolute left-0 top-0 w-8 h-8 bg-surface-container-highest rounded-full flex items-center justify-center border border-primary-container/50 z-10">
<span class="text-primary-container font-headline font-bold text-sm">01</span>
</div>
<h4 class="text-primary font-bold mb-1">Trigger Request</h4>
<p class="text-on-surface-variant text-sm">Send `/buy` command to the ZiVPN Telegram Bot with desired package.</p>
</div>
<!-- Step 2 -->
<div class="relative pl-12">
<div class="absolute left-0 top-0 w-8 h-8 bg-surface-container-highest rounded-full flex items-center justify-center border border-primary-container/50 z-10">
<span class="text-primary-container font-headline font-bold text-sm">02</span>
</div>
<h4 class="text-primary font-bold mb-1">Dynamic QRIS</h4>
<p class="text-on-surface-variant text-sm">System generates a unique QRIS image with embedded tracking bits.</p>
<div class="mt-4 glass-panel p-4 rounded-lg flex justify-center">
<img alt="QR Code" class="w-32 h-32 opacity-80 mix-blend-screen" data-alt="a minimalist glowing cyan qr code displayed on a dark high tech digital interface screen" src="https://lh3.googleusercontent.com/aida-public/AB6AXuA-6YZfOmXxUYfEEMuPG2dNC4q_2aFU9wutm0a5H3aZyDOyu-C6cdgJTYYZVdu5-L9mJTvv93MRY1eKIyvIcxfUiJNI60bMbXL12LSWwtPhN_Bxr2Uisiy98Rv6r6qyKRbyjSVvAQQ1yCZ9xVBw3sUBnwFu5B2_OxDO7NuwLbuNu-HE8a7eSCaA4OUSKITlpPtckFOMPIK3mi67D2QOu_BtmXPIVu67uVwT7hKgN6V3kZwTADJBDYc3a2bBPRlx5UTj06Z2rvUw5SxP"/>
</div>
</div>
<!-- Step 3 -->
<div class="relative pl-12">
<div class="absolute left-0 top-0 w-8 h-8 bg-surface-container-highest rounded-full flex items-center justify-center border border-primary-container/50 z-10">
<span class="text-primary-container font-headline font-bold text-sm">03</span>
</div>
<h4 class="text-primary font-bold mb-1">Instant Activation</h4>
<p class="text-on-surface-variant text-sm">Payment confirmed in &lt; 5s. Kinetic tunnel credentials sent instantly.</p>
</div>
</div>
</section>
<!-- Technical Specs -->
<section class="px-6 py-16">
<div class="flex items-center justify-between mb-8">
<h2 class="text-2xl font-headline font-bold text-primary">Technical Specs</h2>
<span class="text-outline text-xs font-mono uppercase">config_v1.json</span>
</div>
<div class="bg-surface-container-lowest rounded-lg border border-outline-variant/20 overflow-hidden mb-8">
<div class="bg-surface-container-highest px-4 py-2 flex items-center gap-2">
<div class="w-2 h-2 rounded-full bg-error"></div>
<div class="w-2 h-2 rounded-full bg-primary-container"></div>
<div class="w-2 h-2 rounded-full bg-secondary"></div>
</div>
<pre class="p-6 text-xs font-mono text-primary overflow-x-auto no-scrollbar">{
  "provider": "ZiVPN_Global",
  "protocol": "UDP_KINETIC",
  "endpoint": "gateway.zivpn.eth",
  "auth": {
    "type": "dynamic_token",
    "refresh_rate": "3600s"
  },
  "payment": {
    "gateway": "QRIS_DYNAMIC",
    "currency": "IDR"
  }
}</pre>
</div>
<!-- Bot Commands Table -->
<div class="overflow-x-auto">
<table class="w-full text-left border-collapse">
<thead>
<tr class="border-b border-outline-variant/30">
<th class="py-4 font-headline text-primary-container text-xs uppercase tracking-widest">Command</th>
<th class="py-4 font-headline text-primary-container text-xs uppercase tracking-widest">Action</th>
</tr>
</thead>
<tbody class="text-sm">
<tr class="border-b border-outline-variant/10">
<td class="py-4 font-mono text-primary">/status</td>
<td class="py-4 text-on-surface-variant">Check server load &amp; latency</td>
</tr>
<tr class="border-b border-outline-variant/10">
<td class="py-4 font-mono text-primary">/renew</td>
<td class="py-4 text-on-surface-variant">Extend tunnel duration</td>
</tr>
<tr>
<td class="py-4 font-mono text-primary">/logs</td>
<td class="py-4 text-on-surface-variant">View traffic telemetry</td>
</tr>
</tbody>
</table>
</div>
</section>
<!-- Troubleshooting Accordion -->
<section class="px-6 py-16 bg-surface-container-low">
<h2 class="text-2xl font-headline font-bold text-primary mb-8">Troubleshooting</h2>
<div class="space-y-4">
<details class="group bg-surface-container-high rounded-lg" open="">
<summary class="list-none p-4 flex items-center justify-between cursor-pointer">
<span class="text-primary font-medium text-sm">UDP Fragmentation Errors</span>
<span class="material-symbols-outlined text-outline group-open:rotate-180 transition-transform" data-icon="expand_more">expand_more</span>
</summary>
<div class="px-4 pb-4 text-on-surface-variant text-xs leading-relaxed">
                        Adjust MTU settings in your configuration file. We recommend 1350 for unstable cellular networks.
                    </div>
</details>
<details class="group bg-surface-container-high rounded-lg">
<summary class="list-none p-4 flex items-center justify-between cursor-pointer">
<span class="text-primary font-medium text-sm">QRIS Not Generating</span>
<span class="material-symbols-outlined text-outline group-open:rotate-180 transition-transform" data-icon="expand_more">expand_more</span>
</summary>
<div class="px-4 pb-4 text-on-surface-variant text-xs leading-relaxed">
                        Verify your API callback URL is reachable. Check firewall settings on port 443.
                    </div>
</details>
</div>
</section>
</main>
<!-- Footer -->
<footer class="bg-[#0a0e14] w-full py-12 font-['Inter'] text-sm tracking-wide">
<div class="max-w-7xl mx-auto px-8 flex flex-col md:flex-row justify-between items-center gap-6">
<div class="flex flex-col items-center md:items-start gap-2">
<span class="text-lg font-bold text-[#dbfcff]">ZiVPN</span>
<p class="text-[#b9cacb] text-center md:text-left">© 2024 ZiVPN Kinetic Ether. All rights reserved.</p>
</div>
<div class="flex flex-wrap justify-center gap-6">
<a class="text-[#b9cacb] hover:text-[#dbfcff] underline decoration-[#00f0ff] transition-all opacity-80 hover:opacity-100" href="#">Documentation</a>
<a class="text-[#b9cacb] hover:text-[#dbfcff] underline decoration-[#00f0ff] transition-all opacity-80 hover:opacity-100" href="#">Privacy Policy</a>
<a class="text-[#b9cacb] hover:text-[#dbfcff] underline decoration-[#00f0ff] transition-all opacity-80 hover:opacity-100" href="#">Status</a>
<a class="text-[#b9cacb] hover:text-[#dbfcff] underline decoration-[#00f0ff] transition-all opacity-80 hover:opacity-100" href="#">Support</a>
</div>
</div>
</footer>
<!-- Bottom Nav for Mobile -->
<nav class="md:hidden fixed bottom-0 left-0 right-0 bg-surface-container-lowest/80 backdrop-blur-md px-6 py-3 flex justify-around items-center z-50 border-t border-outline-variant/10">
<button class="flex flex-col items-center gap-1 text-primary-container">
<span class="material-symbols-outlined" data-icon="home" style="font-variation-settings: 'FILL' 1;">home</span>
<span class="text-[10px] font-label font-bold uppercase">Home</span>
</button>
<button class="flex flex-col items-center gap-1 text-on-surface-variant">
<span class="material-symbols-outlined" data-icon="menu_book">menu_book</span>
<span class="text-[10px] font-label font-bold uppercase">Docs</span>
</button>
<button class="flex flex-col items-center gap-1 text-on-surface-variant">
<span class="material-symbols-outlined" data-icon="monitoring">monitoring</span>
<span class="text-[10px] font-label font-bold uppercase">Status</span>
</button>
<button class="flex flex-col items-center gap-1 text-on-surface-variant">
<span class="material-symbols-outlined" data-icon="person">person</span>
<span class="text-[10px] font-label font-bold uppercase">Bot</span>
</button>
</nav>
</body></html>
