import css from "../css/stormwind.scss";
import RecipientPortal from "./ui/RecipientPortal.svelte";
import Login from "./ui/pages/Login.svelte";
import TermsNotAccepted from "./ui/pages/TermsNotAccepted.svelte";
import MidLogin from "./ui/pages/MidLogin.svelte";
import RecipientDeleted from "./ui/pages/RecipientDeleted.svelte";
import BadAdhoc from "./ui/pages/BadAdhoc.svelte";
import RecipientCompanyChoice from "./ui/pages/RecipientCompanyChoice.svelte";
import Unauthenticated from "./ui/pages/errors/Unauthenticated.svelte";
import MFAAskCode from "./ui/pages/errors/MFAAskCode.svelte";
import AdhocPackage from "./ui/pages/adhoc/AdhocPackage.svelte";
import ForgotPassword from "./ui/pages/ForgotPassword.svelte";
import ResetPassword from "./ui/pages/ResetPassword.svelte";

import { getEnabledFeatures } from "BoilerplateAPI/Features";
import { getWhitelabeling } from "BoilerplateAPI/RecipientPortal";
import VerifySignature from "./ui/components/Signature/VerifySignature.svelte";
import IACSignatureOk from "./ui/components/Signature/IACSignatureOk.svelte";
import BadSignature from "./ui/components/Signature/BadSignature.svelte";

let app;
let role = document.getElementById("stormwind-page-role").dataset["role"];
let container = document.getElementById("stormwind-base-container");

let params = JSON.parse(
  document.getElementById("stormwind-page-params").dataset["params"]
);

let roleimp = document.getElementById("stormwind-page-roleimp").dataset[
  "params"
];

window.__boilerplate_roleimp = roleimp;

console.log(
  `Boilerplate "Stormwind" boot: role=${role} startingHash=${
    window.location.hash
  } params=${JSON.stringify(params)}`
);

// cache the features
getEnabledFeatures().then((ff) => {
  window.__boilerplate_features = ff;
});

getWhitelabeling("recipient").then((xx) => {
  if (xx.enabled) {
    window.__boilerplate_whitelabel_image = xx.logo_url;
  }
});

if (role == "recipient") {
  app = new RecipientPortal({
    target: container,
    props: {
      name: "Svelte + Elixir",
    },
  });
} else if (role == "login") {
  app = new Login({
    target: container,
    props: {
      name: "Hello, Svelte",
    },
  });
} else if (role == "midlogin") {
  app = new MidLogin({
    target: container,
    props: {
      email: params["email"],
    },
  });
} else if (role == "recipient_choose") {
  app = new RecipientCompanyChoice({
    target: container,
    props: {
      name: "Hello, Svelte",
    },
  });
} else if (role == "adhoc_package") {
  app = new AdhocPackage({
    target: container,
    props: {
      adhoc_string: params["adhoc_string"],
      name: "Hello, Svelte",
    },
  });
} else if (role == "reset_password") {
  app = new ResetPassword({
    target: container,
    props: {
      lhash: params["lhash"],
      uid: params["uid"],
      email: params["email"],
    },
  });
} else if (role == "forgot_password") {
  app = new ForgotPassword({
    target: container,
    props: {
      fw: "1",
    },
  });
} else if (role == "unauthenticated") {
  app = new Unauthenticated({
    target: container,
    props: {
      name: "Hello, Svelte",
    },
  });
} else if (role == "mfa_ask_code") {
  app = new MFAAskCode({
    target: container,
    props: {
      name: "Hello, Svelte",
      recipient_uid: params["user_id"],
      mfa_type: params["type"],
    },
  });
} else if (role == "terms_not_accepted") {
  app = new TermsNotAccepted({
    target: container,
    props: {
      name: "Hello, Svelte",
      recipient_uid: params["user_id"],
    },
  });
} else if (role == "verify_signature") {
  app = new VerifySignature({
    target: container,
    props: {
      name: "Hello, Svelte",
    },
  });
} else if (role == "signature_ok") {
  const { signer_name, signer_email, audit_ip, document_title, inserted_at } =
    params;
  app = new IACSignatureOk({
    target: container,
    props: {
      signerName: signer_name,
      signerEmail: signer_email,
      auditIP: audit_ip,
      documentTitle: document_title,
      insertedAt: inserted_at,
    },
  });
} else if (role == "bad_signature") {
  app = new BadSignature({
    target: container,
    props: {
      name: "Hello, Svelte",
    },
  });
} else if (role == "recipient_deleted") {
  app = new RecipientDeleted({
    target: container,
  });
} else if (role == "bad_adhoc") {
  app = new BadAdhoc({
    target: container,
  });
} else {
  alert(
    "Sorry, Boilerplate UI failed to initialize, due to a missing role: " + role
  );
}

window.app = app;
export default app;
