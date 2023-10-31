<script>
	import FAIcon from "./FAIcon.svelte";
	export let text;
	export let color = "primary";
	export let type = "button";
	export let icon = "";
	export let iconStyle = "";
	export let iconLocation = "left";
	export let disabled = false;
</script>

<style>
button {
	display: inline-block;
	border-style: solid;
	border-radius: 4px;
	cursor: pointer;
	padding: 0rem 1.5rem;

	font-family: 'Nunito', sans-serif;
	font-style: normal;
	font-weight: 500;
	font-size: 14px;
	line-height: 16px;
	max-height: 40px;
	/* identical to box height, or 114% */
	text-align: center;
	text-decoration: none;
	letter-spacing: 0.02em;
	text-transform: capitalize;
	white-space: nowrap;
	color: #FFFFFF;

	filter: drop-shadow(0px 3px 4px rgba(46, 56, 77, 0.12));
    padding: 0.5rem 0.75rem 0.5rem 0rem;
}

button:hover:enabled {
	box-shadow: 0px 3px 20px 7px rgba(46, 56, 77, 0.22);	
}

button:active:enabled {
	filter: brightness(0.8);
}

.primary {
	background: #2A2F34;
	border-color: #2A2F34;
}

.secondary {
	background: #4BADF3;
	border-color: #4BADF3;
}

.danger {
	background: #FCE7E7;
	border-color: #FCE7E7;
	color: #DB5244;
}

.warning {
	background: #FBEED7;
	border-color: #FBEED7;
	color: #EDA839;
}

.green {
	background: #EAF7F0;
	border-color: #EAF7F0;
	color: #54CC86;
}

.light {
	background: #E9F1FA;
	border-color: #E9F1FA;
	color: #2A2F34;
}

.disabled {
	background: #B3C1D0;
	border-color: #B3C1D0;
	color: #FFFFFF;
	cursor: not-allowed;
}
</style>

<button {type} class="{color}" {disabled} class:disabled >
{#if iconLocation == "left"}
	{#if icon != ""} <FAIcon {icon} {iconStyle} rightPad/> {/if}
	{text}
{:else}
	{text}
	{#if icon != ""} <FAIcon {icon} {iconStyle} leftPad/> {/if}
{/if}
</button>