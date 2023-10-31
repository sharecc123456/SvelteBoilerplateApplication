<script>
  export let lato = false;
  export let normal = false;
</script>

<style>
p {  
	/* Heading 3 - 28px */
	font-family: 'Nunito', sans-serif;
	font-style: normal;
	font-weight: bold;
	font-size: 28px;
	line-height: 34px;
	/* identical to box height, or 121% */
	/* Black */
	color: #2A2F34;

	/* overwrite the UA SS */
	margin-block-end: 0;
}

  .lato {
    font-family: 'Lato', sans-serif;
  }

  .normal {
    font-weight: normal;
  }
</style>

<p class:lato={lato} class:normal={normal}><slot></slot></p>