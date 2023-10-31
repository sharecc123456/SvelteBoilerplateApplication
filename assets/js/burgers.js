var burgers = {
  init: () => {
    const $navbarBurgers = Array.prototype.slice.call(document.querySelectorAll('.navbar-burger'), 0);
    if ($navbarBurgers.length > 0) {

      document.addEventListener('click', function(e) {
        $navbarBurgers.forEach(el => {
          const target = el.dataset.target;
          const $target = document.getElementById(target);
          el.classList.remove('is-active');
          $target.classList.remove('is-active');
        });
      });

      document.addEventListener('keydown', function (event) {
        var e = event || window.event;
        if (e.keyCode === 27) {
          $navbarBurgers.forEach(el => {
            const target = el.dataset.target;
            const $target = document.getElementById(target);
            el.classList.remove('is-active');
            $target.classList.remove('is-active');
          });
        }
      });

      $navbarBurgers.forEach( el => {
        el.addEventListener('click', (e) => {
          const target = el.dataset.target;
          const $target = document.getElementById(target);
          el.classList.toggle('is-active');
          $target.classList.toggle('is-active');
          e.stopPropagation();
       });
      });
    }

    const $burgerLikes = Array.prototype.slice.call(document.querySelectorAll('.bp-burgerlike'), 0);
    if ($burgerLikes.length > 0) {
      $burgerLikes.forEach( el => {
        el.addEventListener('click', () => {
          const target = el.dataset.target;
          const $target = document.getElementById(target);
          el.classList.toggle('is-active');
          $target.classList.toggle('is-active');
       });
      });
    }
  }
}

export default burgers;
