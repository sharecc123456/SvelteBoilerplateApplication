<script context="module">
	export function faicon_for_status(s) {
		switch(s) {
			case 0: return "circle";
			case 1: return "adjust";
			case 2: return "check-circle";
			case 3: return "undo";
		}
	}

	export function status_to_text(s) {
		switch(s) {
			case 0: return "New";
			case 1: return "Open";
			case 2: return "Submitted";
			case 3: return "Returned";
		}
	}
	export function status_to_class(s) {
		switch(s) {
			case 0: return "";
			case 1: return "";
			case 2: return "";
			case 3: return "returned-text";
		}
	}
	export function status_to_buttontext(s) {
		switch(s) {
			case 0: return "Start";
			case 1: return "Continue";
			case 2: return "View";
			case 3: return "Fix Issues";
			case 4: return "View";
			case 7: return "Continue";
		}
	}

	export function fastyle_for_status(s) {
		if (s == 0)
			return "regular";

		return "solid";
	}
</script>
