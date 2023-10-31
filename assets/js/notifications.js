function init() {
  // notifications
  (document.querySelectorAll('.notification .delete') || []).forEach(($delete) => {
    const $notification = $delete.parentNode;
    $delete.addEventListener('click', () => {
      $notification.parentNode.removeChild($notification);
    });
  });
}

var notifications = {
  init: () => {
    init();
  },
};

export default notifications;
