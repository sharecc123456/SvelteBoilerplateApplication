function init_old() {
  if (document.getElementById("bp-stripe-client-secret") == null) {
    return;
  }
  var public_key = document.getElementById("bp-stripe-client-pk").value;
  var stripe = Stripe(public_key);
  var elements = stripe.elements();

  // Set up Stripe.js and Elements to use in checkout form
  var style = {
    base: {
      color: "#32325d",
    }
  };

  var card = elements.create("card", { style: style });
  card.mount("#card-element");

  card.addEventListener('change', ({error}) => {
  const displayError = document.getElementById('card-errors');
  if (error) {
    displayError.textContent = error.message;
  } else {
    displayError.textContent = '';
  }
  });

  var submitButton = document.getElementById('submit');
  var clientSecret = document.getElementById('bp-stripe-client-secret').value;

  submitButton.addEventListener('click', function(ev) {
    stripe.confirmCardPayment(clientSecret, {
      payment_method: {card: card}
    }).then(function(result) {
      if (result.error) {
        alert("Eww failed: " + result.error.message);
        console.log(result.error.message);
      } else {
        // The payment has been processed!
        if (result.paymentIntent.status === 'succeeded') {
          alert("Successful!");
        }
      }
    });
  });
}

function init()
{
  var xsx = document.getElementById("bp-stripe-checkout-session-id");
  if (xsx == null) {
    return;
  }
  var public_key = document.getElementById("bp-stripe-client-pk").value;
  var stripe = Stripe(public_key);

  stripe.redirectToCheckout({
    sessionId: xsx.value
  }).then(function (result) {
    alert("Stripe error: "+ result.error.message);
    // If `redirectToCheckout` fails due to a browser or network
    // error, display the localized error message to your customer
    // using `result.error.message`.
  });
}

var bpstripe = {
  init: () => {
    try {
      init();
    } catch (e) {
      alert("error bpstripe: " + e.message);
    }
  },
}

export default bpstripe;
