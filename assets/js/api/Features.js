export async function getEnabledFeatures() {
  let request = await fetch("/n/api/v1/internal/features", {
    credentials: "include",
  });

  if (request.ok) {
    let data = await request.json();

    return data.enabled_flags;
  }

  return [];
}

export async function getCompanyInfo() {
  let request = await fetch("/n/api/v1/company/info", {
    credentials: "include",
  });

  if (request.ok) {
    let data = await request.json();

    return data;
  }

  return { mfa_mandate: false, integrations: [] };
}
