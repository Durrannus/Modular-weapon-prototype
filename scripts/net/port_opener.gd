extends RefCounted
## Asks the home router to let the other player in.
##
## Most home routers block connections coming in from the internet. Many will
## open one port when a program on the network asks them to (this is called
## UPnP). This asks, and reports the address the other player should type.
## Talking to the router can take a couple of seconds, so it happens on a thread.
##
## state: "asking"  still talking to the router
##        "open"    the router opened the port; `address` is this home's internet address
##        "shared"  the router answered, but it isn't directly on the internet itself
##                  (the internet provider shares one address between many homes),
##                  so opening its port doesn't help
##        "failed"  the router didn't answer or said no

var state := "asking"
var address := ""

var _thread: Thread
var _upnp: UPNP
var _port := 0
var _closing := false

static var _finishing: Array = []   # threads still tidying up after their opener was closed


func open(port: int) -> void:
	_port = port
	_thread = Thread.new()
	_thread.start(_work)


func _work() -> Dictionary:
	var u := UPNP.new()
	if u.discover(2000, 2, "InternetGatewayDevice") != UPNP.UPNP_RESULT_SUCCESS:
		return {"ok": false}
	var gateway := u.get_gateway()
	if gateway == null or not gateway.is_valid_gateway():
		return {"ok": false}
	if u.add_port_mapping(_port, _port, "Modular Weapon Prototype", "UDP", 0) != UPNP.UPNP_RESULT_SUCCESS:
		return {"ok": false}
	if _closing:
		# The player left while we were asking: put things back.
		u.delete_port_mapping(_port, "UDP")
		return {"ok": false}
	return {"ok": true, "address": u.query_external_address(), "upnp": u}


## Call now and then. True when there is news.
func poll() -> bool:
	_reap()
	if _thread == null or _thread.is_alive():
		return false
	var result: Dictionary = _thread.wait_to_finish()
	_thread = null
	if not result.get("ok", false):
		state = "failed"
		return true
	_upnp = result["upnp"]
	address = str(result.get("address", ""))
	state = "shared" if address == "" or is_private(address) else "open"
	return true


## Closes the port on the router again.
func close() -> void:
	_closing = true
	if _thread != null:
		_finishing.append(_thread)
		_thread = null
	elif _upnp != null:
		var u := _upnp
		var port := _port
		var t := Thread.new()
		t.start(func(): u.delete_port_mapping(port, "UDP"))
		_finishing.append(t)
		_upnp = null
	_reap()


static func _reap() -> void:
	for t in _finishing.duplicate():
		if not (t as Thread).is_alive():
			(t as Thread).wait_to_finish()
			_finishing.erase(t)


## True for addresses that only work inside a home or a provider's own network.
static func is_private(ip: String) -> bool:
	var p := ip.split(".")
	if p.size() != 4:
		return false
	var a := int(p[0])
	var b := int(p[1])
	return a == 10 or a == 127 or (a == 192 and b == 168) or (a == 172 and b >= 16 and b <= 31) or (a == 100 and b >= 64 and b <= 127) or (a == 169 and b == 254)
