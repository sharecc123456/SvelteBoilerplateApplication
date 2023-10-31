let enabled = false;

async function reportCrash(loc, crash_body) {
  if (enabled) {
    await fetch("/n/api/v1/internal/crashreport", {
      method: "POST",
      credentials: "include",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        crash: {
          "boilerplate-version": "boilerplate-42",
          locationIdentifier: loc,
          js_error: crash_body,
        },
      }),
    });
  } else {
    console.log(`JS CRASH @ ${loc}: ${crash_body}`);
  }
}

export { reportCrash };
