<script>
  export let toggleMenu;
  function handleClick(){
    toggleMenu = true;
  }
</script>

<div class="menu {toggleMenu ? 'open' : ''}" on:click={handleClick}>
  <span></span>
  <span></span>
  <span></span>
</div>
<style>
.menu {
  width: 35px;
  height: 30px;
  -webkit-transform: rotate(0deg);
  -moz-transform: rotate(0deg);
  -o-transform: rotate(0deg);
  transform: rotate(0deg);
  -webkit-transition: .5s ease-in-out;
  -moz-transition: .5s ease-in-out;
  -o-transition: .5s ease-in-out;
  transition: .5s ease-in-out;
  cursor: pointer;
  margin-right: 15px;
}

.menu span {
  display: block;
  position: absolute;
  height: 5px;
  width: 100%;
  background: grey;
  border-radius: 5px;
  opacity: 1;
  left: 0;
  -webkit-transform: rotate(0deg);
  -moz-transform: rotate(0deg);
  -o-transform: rotate(0deg);
  transform: rotate(0deg);
  -webkit-transition: .25s ease-in-out;
  -moz-transition: .25s ease-in-out;
  -o-transition: .25s ease-in-out;
  transition: .25s ease-in-out;
}
.open{
  pointer-events: none;
}

.menu span:nth-child(1) {
  top: 0px;
  -webkit-transform-origin: left center;
  -moz-transform-origin: left center;
  -o-transform-origin: left center;
  transform-origin: left center;
}

.menu span:nth-child(2) {
  top: 12px;
  -webkit-transform-origin: left center;
  -moz-transform-origin: left center;
  -o-transform-origin: left center;
  transform-origin: left center;
}

.menu span:nth-child(3) {
  top: 24px;
  -webkit-transform-origin: left center;
  -moz-transform-origin: left center;
  -o-transform-origin: left center;
  transform-origin: left center;
}

.menu.open span:nth-child(1) {
  -webkit-transform: rotate(45deg);
  -moz-transform: rotate(45deg);
  -o-transform: rotate(45deg);
  transform: rotate(45deg);
  top: -3px;
  left: 8px;
}

.menu.open span:nth-child(2) {
  width: 0%;
  opacity: 0;
}

.menu.open span:nth-child(3) {
  -webkit-transform: rotate(-48deg);
  -moz-transform: rotate(-48deg);
  -o-transform: rotate(-48deg);
  transform: rotate(-48deg);
  top: 22px;
  left: 9px;
}


@media (max-width: 400px) {
  .menu{
    margin-right: 0px;
    margin-top: 8px;
    margin-left: 5px;
  }
  .menu span{
    width: calc(100% - 10px);
  }
  .menu span:nth-child(2) {
    top: 8px;
  }
  .menu span:nth-child(3) {
    top: 16px;
  }
  .menu.open span:nth-child(1) {
    top: 2px;
    left: 8px;
  }
  .menu.open span:nth-child(3) {
    top: 20px;
    left: 9px;
  }
}
</style>