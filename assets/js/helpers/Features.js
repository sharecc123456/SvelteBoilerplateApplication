import { getEnabledFeatures, getCompanyInfo } from "BoilerplateAPI/Features";
import {
  sessionStorageGet,
  sessionStorageHas,
  sessionStorageSave,
} from "Helpers/sessionStorageHelper";

export function featureEnabled(ff) {
  const features = window.__boilerplate_features;

  if (features == null || features == undefined) {
    getEnabledFeatures().then((ff) => {
      window.__boilerplate_features = ff;
    });
    return false;
  }

  return features.includes(ff);
}

async function __mfaPopupNeeded() {
  let mfaMandateNeeded = window.__boilerplate_mfa_mandate;
  let mfaSetup = window.__boilerplate_mfa_setup;

  if (mfaMandateNeeded == null || mfaMandateNeeded == undefined) {
    let info = await getCompanyInfo();
    window.__boilerplate_mfa_mandate = info.mfa_mandate;
    mfaMandateNeeded = info.mfa_mandate;
  }

  // grab user data
  if (mfaSetup == null || mfaSetup == undefined) {
    let mfa_state = await fetch("/n/api/v1/user/me?type=requestor")
      .then((x) => x.json())
      .then(async (x) => {
        return x.two_factor_state;
      });

    mfaSetup = mfa_state;
    window.__boilerplate_mfa_setup = mfaSetup;
  }

  // check if the user is already MFA setup
  if (mfaMandateNeeded && mfaSetup != 2 && mfaSetup != 4) {
    return true;
  }

  return false;
}

async function __getCompanyId() {
  let info = await getCompanyInfo();
  return info.info.id;
}

export async function mfaPopupNeeded() {
  if (sessionStorageHas("mfa_data")) {
    let obj = sessionStorageGet("mfa_data");
    return obj.needed;
  }

  sessionStorageSave("mfa_data", { needed: await __mfaPopupNeeded() });
}

export async function getCompanyId() {
  if (sessionStorageHas("boilerplate_company_id")) {
    let obj = sessionStorageGet("boilerplate_company_id");
    return obj.id;
  }

  let id = await __getCompanyId();
  sessionStorageSave("boilerplate_company_id", { id: id });

  return id;
}
