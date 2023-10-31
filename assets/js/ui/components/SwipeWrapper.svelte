<script>
  import { createEventDispatcher } from "svelte";
  let startX,
    startY,
    threshold = 25;
  const dispatch = createEventDispatcher();
  function getSwipeEvent(deltaX, deltaY) {
    switch (true) {
      case deltaX >= threshold:
        return "swipeLeft";
      case deltaX <= -threshold:
        return "swipeRight";
      case deltaY >= threshold:
        return "swipeUp";
      case deltaY <= -threshold:
        return "swipeDown";
    }
  }
  function touchStart(e) {
    var touches = e.touches;
    if (touches && touches.length) {
      startX = touches[0].pageX;
      startY = touches[0].pageY;
    }
  }
  function touchMove(e) {
    if (!startX || !startY) return;
    var touches = e.touches;
    if (touches && touches.length) {
      e.preventDefault();
      var deltaX = startX - touches[0].pageX,
        deltaY = startY - touches[0].pageY,
        swipeEvent = getSwipeEvent(deltaX, deltaY);
      if (swipeEvent) {
        dispatch(swipeEvent);
      }
    }
    startX = null;
    startY = null;
  }
</script>

<div on:touchstart={touchStart} on:touchmove={touchMove}>
  <slot />
</div>
