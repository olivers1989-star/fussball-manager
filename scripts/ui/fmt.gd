class_name Fmt
extends RefCounted
## Formatierungs-Helfer für Geldbeträge und Anzeige-Strings.

static func money(n: int) -> String:
	var neg := n < 0
	var a: int = absi(n)
	var s: String
	if a >= 1000000:
		s = ("%.2f" % (a / 1000000.0)).replace(".", ",") + " Mio. €"
	else:
		s = thousands(a) + " €"
	return ("-" + s) if neg else s

static func thousands(a: int) -> String:
	var s := str(a)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count % 3 == 0 and i > 0:
			result = "." + result
	return result

static func form_str(f: float) -> String:
	return ("%.2f" % f).replace(".", ",")
