class_name Shop
extends Node

# Cosmetic shop. Every product is a one-time purchase: restorable, never expires, priced by the App
# Store in the player's own currency, and none of it changes speed, damage or armour. No coins/gems
# (a currency layer hides what things cost), no timers, no loot boxes.
# Backends: "storekit" on iPhone (tools/storekit plugin, ClassDB "GodotIap"); "desktop" for the free
# desktop builds (no store: everything unlocked); "fake" with --fake-store (a test double that starts
# empty and buys after a beat; --fake-store-cancel makes every purchase a cancel; --fake-store-noprices
# makes every price fetch fail).
signal changed # ownership, prices or a busy purchase moved
signal notice(text: String) # one line for the player
signal bought(p: String) # a purchase this player just made went through

const PREFIX := "com.toyplanesim.game."
# Items: "livery:N" (Planes.LIVERIES), "trail:N" (index into Planes.trail_names(); 6+ are premium),
# "killfx:N" (Planes.KILL_FX). inr = the price we set in App Store Connect, used only as the test
# double's price; the shop shows Apple's displayPrice.
const PRODUCTS := {
	"bundle.all": {title = "Collector's Hangar", cat = 0, inr = 499, items = ["livery:1", "livery:2", "livery:3", "livery:4", "trail:6", "trail:7", "trail:8", "trail:9", "killfx:1", "killfx:2", "killfx:3"],
		blurb = "Everything in the shop, now and every look in it today."},
	"bundle.golden": {title = "Golden Ace Set", cat = 0, inr = 199, items = ["livery:1", "trail:7", "killfx:1"], blurb = "Polished gold trim, a sparkling gold trail and fireworks on every kill."},
	"bundle.neon": {title = "Neon Night Set", cat = 0, inr = 199, items = ["livery:3", "trail:8", "killfx:2"], blurb = "Glowing cyan and pink, a neon trail and a lightning strike on every kill."},
	"bundle.inferno": {title = "Inferno Set", cat = 0, inr = 199, items = ["livery:4", "trail:9", "killfx:3"], blurb = "Molten orange trim, a fire trail and a ring of flame on every kill."},
	"livery.golden": {title = "Golden Ace paint", cat = 1, inr = 99, items = ["livery:1"], blurb = "Polished gold trim and caps over your team colour."},
	"livery.phantom": {title = "Black Phantom paint", cat = 1, inr = 99, items = ["livery:2"], blurb = "Stealth black trim with red stripes."},
	"livery.neon": {title = "Neon Night paint", cat = 1, inr = 99, items = ["livery:3"], blurb = "Trim that glows cyan and pink, even at dusk."},
	"livery.inferno": {title = "Inferno paint", cat = 1, inr = 99, items = ["livery:4"], blurb = "Glowing molten orange and yellow trim."},
	"trail.rainbow": {title = "Rainbow trail", cat = 2, inr = 79, items = ["trail:6"], blurb = "Smoke that bands through every colour."},
	"trail.gold": {title = "Gold Sparkle trail", cat = 2, inr = 79, items = ["trail:7"], blurb = "Bright gold smoke that glints in the sun."},
	"trail.neon": {title = "Neon trail", cat = 2, inr = 79, items = ["trail:8"], blurb = "Glowing cyan fading to pink."},
	"trail.fire": {title = "Fire trail", cat = 2, inr = 79, items = ["trail:9"], blurb = "White-hot to orange flame, then smoke."},
	"kill.fireworks": {title = "Fireworks kill effect", cat = 3, inr = 79, items = ["killfx:1"], blurb = "Three starbursts where your target goes down. Everyone sees it."},
	"kill.lightning": {title = "Lightning kill effect", cat = 3, inr = 79, items = ["killfx:2"], blurb = "A bolt from the sky and a thunderclap. Everyone sees it."},
	"kill.blaze": {title = "Blaze kill effect", cat = 3, inr = 79, items = ["killfx:3"], blurb = "A ring of fire bursts out from the hit. Everyone sees it."},
}
const CATEGORIES := ["SETS", "PAINT JOBS", "SMOKE TRAILS", "KILL EFFECTS"]
const FREE_TRAILS := 6 # Planes.BANNERS: None + 5 colours
const NO_STORE := "Can't reach the App Store. Check your connection and try again."

var backend := "desktop"
var owned := {} # product -> true
var prices := {} # product -> Apple's localized price string
var amounts := {} # product -> numeric price in the storefront's currency
var busy := "" # product being bought
var fetching := false
var fetch_at := -100000 # msec of the last price fetch
var store_down := false # last price fetch failed
var restoring := 0 # 1 waiting for AppStore.sync, 2 for the owned list after it
var fake_fail := false
var trying: Array = [] # items worn on a free solo test flight
var offered := false # one win offer per session
var native: Object


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--fake-store" in args:
		backend = "fake"
		fake_fail = "--fake-store-noprices" in args
		var cfg := ConfigFile.new()
		if cfg.load("user://fake_store.cfg") == OK:
			owned = cfg.get_value("store", "owned", {})
	elif ClassDB.class_exists("GodotIap") and ClassDB.can_instantiate("GodotIap"):
		backend = "storekit"
		if not Engine.has_meta("iap"): # one per process: a scene reload mid-purchase must not drop its result
			Engine.set_meta("iap", ClassDB.instantiate("GodotIap"))
		native = Engine.get_meta("iap")
		native.purchase_updated.connect(_on_purchase)
		native.purchase_error.connect(_on_error)
		native.products_fetched.connect(_on_async)
		native.call("initConnection")
		native.call("getAvailablePurchases", "{}")
	fetch()


# Prices, again whenever some are missing (slow or offline sandbox): at most every 10 s unless the
# player asks, and a fetch with no answer in 15 s counts as failed.
func fetch(force := false) -> void:
	if backend == "desktop" or fetching or prices.size() == PRODUCTS.size() or (not force and Time.get_ticks_msec() - fetch_at < 10000):
		return
	fetching = true
	fetch_at = Time.get_ticks_msec()
	changed.emit()
	if backend == "fake":
		var list := [] if fake_fail else PRODUCTS.keys().map(func(p): return {id = PREFIX + p, displayPrice = "₹%d" % PRODUCTS[p].inr, price = PRODUCTS[p].inr})
		_on_async({method = "fetchProducts", success = not fake_fail, productsJson = JSON.stringify(list)})
		return
	native.call("fetchProducts", JSON.stringify({skus = PRODUCTS.keys().map(func(p): return PREFIX + p)}))
	var at := fetch_at
	get_tree().create_timer(15.0).timeout.connect(func():
		if fetching and fetch_at == at:
			_on_async({method = "fetchProducts"}))


func sells() -> bool:
	return backend != "desktop"


func owns_product(p: String) -> bool: # bought, or every piece of it came in a set
	return backend == "desktop" or owned.has(p) or PRODUCTS[p].items.all(owns)


func owns(item: String) -> bool:
	if Progress.reward_level(item) > 0: # earned on the pilot level track, never sold
		return Progress.has(item)
	if _free(item) or backend == "desktop":
		return true
	for p in owned:
		if item in PRODUCTS.get(p, {}).get("items", []):
			return true
	return false


static func _free(item: String) -> bool:
	var n := int(item.get_slice(":", 1))
	return n == 0 or (item.begins_with("trail:") and n < FREE_TRAILS)


func price(p: String) -> String:
	return prices.get(p, "")


# Honest bundle saving against buying the same pieces one by one, from this storefront's own prices
# (0, so no claim, until they are all known).
func saving(p: String) -> int:
	var parts := 0.0
	for item in PRODUCTS[p].items:
		for q in PRODUCTS:
			if PRODUCTS[q].items == [item]:
				if not amounts.has(q):
					return 0
				parts += amounts[q]
	var whole: float = amounts.get(p, 0.0)
	return roundi(100.0 * (1.0 - whole / parts)) if whole > 0.0 and parts > whole else 0


# Cheapest single product that unlocks an item (what a locked hangar row opens on).
func product_for(item: String) -> String:
	for p in PRODUCTS:
		if PRODUCTS[p].items == [item]:
			return p
	return "bundle.all"


func buy(p: String) -> void:
	if busy != "" or owns_product(p):
		return
	busy = p
	changed.emit()
	match backend:
		"storekit":
			native.call("requestPurchaseWithPayload", JSON.stringify({requestPurchase = {apple = {sku = PREFIX + p}}}))
		"fake":
			await get_tree().create_timer(0.6).timeout
			if "--fake-store-cancel" in OS.get_cmdline_user_args():
				_on_error({code = "user-cancelled", productId = PREFIX + p})
			else:
				_on_purchase({productId = PREFIX + p, transactionId = str(Time.get_ticks_usec())})


func restore() -> void:
	if restoring:
		return
	match backend:
		"storekit":
			restoring = 1
			notice.emit("Checking the App Store...")
			native.call("restorePurchases")
		"fake":
			_restored()


func _restored() -> void:
	restoring = 0
	var n := owned.size()
	notice.emit("Restored %d purchase%s." % [n, "" if n == 1 else "s"] if n > 0 else "No previous purchases found for this Apple ID.")


func _on_purchase(purchase: Dictionary) -> void:
	var p := str(purchase.get("productId", "")).trim_prefix(PREFIX)
	if not PRODUCTS.has(p):
		return
	if purchase.get("purchaseState", "") == "revoked": # refunded or Family Sharing ended; the bridge finished it
		owned.erase(p)
		changed.emit()
		return
	var fresh := not owned.has(p)
	var mine := busy == p
	owned[p] = true
	if mine:
		busy = ""
	if backend == "storekit":
		native.call("finishTransaction", JSON.stringify({purchase = purchase}))
	elif backend == "fake":
		_save_fake()
	if fresh:
		notice.emit("Unlocked: %s. Thanks for supporting the game!" % PRODUCTS[p].title)
		if mine:
			bought.emit(p)
	changed.emit()


func _on_error(error: Dictionary) -> void:
	busy = ""
	match str(error.get("code", "")):
		"user-cancelled":
			notice.emit("Purchase cancelled. Nothing was charged.")
		"deferred":
			notice.emit("Waiting for approval (Ask to Buy). It unlocks once approved.")
		"network":
			notice.emit("No connection to the App Store. Try again in a moment.")
		"unverified":
			notice.emit("The App Store couldn't verify this purchase. Tap Restore Purchases to try again.")
		_:
			notice.emit("The purchase didn't go through. Nothing was charged.")
	changed.emit()


func _on_async(result: Dictionary) -> void:
	match str(result.get("method", "")):
		"fetchProducts":
			fetching = false
			var list = JSON.parse_string(str(result.get("productsJson", "[]")))
			for prod in (list if list is Array else []):
				var p := str(prod.get("id", "")).trim_prefix(PREFIX)
				prices[p] = str(prod.get("displayPrice", ""))
				if prod.has("price"):
					amounts[p] = float(prod.price)
			var was_down := store_down
			store_down = prices.is_empty() or not result.get("success", false) and prices.size() < PRODUCTS.size()
			if store_down:
				notice.emit(NO_STORE)
			elif was_down:
				notice.emit("")
		"getAvailablePurchases":
			var list = JSON.parse_string(str(result.get("purchasesJson", "[]")))
			if result.get("success", false) and list is Array: # StoreKit's verified entitlements are the truth (refunds drop out)
				owned = {}
				for pur in list:
					var p := str(pur.get("productId", "")).trim_prefix(PREFIX)
					if PRODUCTS.has(p):
						owned[p] = true
			if restoring == 2:
				_restored()
		"restorePurchases":
			if result.get("success", false):
				restoring = 2
				native.call("getAvailablePurchases", "{}")
			else:
				restoring = 0
				notice.emit("Restore cancelled." if result.get("code", "") == "user-cancelled" else NO_STORE)
	changed.emit()


func _save_fake() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("store", "owned", owned)
	cfg.save("user://fake_store.cfg")


# What you actually fly: your pick if you own it (or are trying it on a solo flight), else the free look.
func wear(slot: String, solo: bool) -> int:
	var key := "trail" if slot == "banner" else slot
	if solo:
		for item in trying:
			if item.begins_with(key + ":"):
				return int(item.get_slice(":", 1))
	var v := int(Settings.values.get(slot, 0))
	return v if owns("%s:%d" % [key, v]) else 0


# After a win, at most once a session and never in your first 3 matches: one set you don't own,
# rotating, dropped for good after you've said "not now" to it twice.
func offer_after_win() -> String:
	if not sells() or offered or int(Settings.values.get("matches", 0)) < 3:
		return ""
	var sets := ["bundle.golden", "bundle.neon", "bundle.inferno"].filter(func(p):
		return not owns_product(p) and int(Settings.values.offer_dismiss.get(p, 0)) < 2)
	if sets.is_empty() or owns_product("bundle.all") or (backend == "storekit" and price(sets[0]) == ""):
		return ""
	offered = true
	return sets[int(Settings.values.matches) % sets.size()]


func dismiss(p: String) -> void:
	var d: Dictionary = Settings.values.offer_dismiss.duplicate()
	d[p] = int(d.get(p, 0)) + 1
	Settings.values.offer_dismiss = d
	Settings.save()


# Apple's own rating sheet after a win you'll remember: 5+ matches in, at most every 60 days
# (Apple also caps it at 3 a year and may not show it).
func maybe_review() -> void:
	var now := int(Time.get_unix_time_from_system())
	if backend != "storekit" or int(Settings.values.get("matches", 0)) < 5 or now - int(Settings.values.get("review_at", 0)) < 60 * 86400:
		return
	if ClassDB.can_instantiate("GodotReview"):
		ClassDB.instantiate("GodotReview").call("request")
		Settings.values.review_at = now
		Settings.save()
