<script>
  import Button from "../../atomic/Button.svelte";

  import ToastBar from "../../atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "../../../helpers/ToastStorage.js";
  import EmailFaultDialog from "../../components/EmailFaultDialog.svelte";
  import { showFatalError } from "Helpers/Error";

  let toastType = ["success", "error", "default", "white"];
  let ttypeSelected = "default";
  let toastLoc = ["TL", "TM", "TR", "ML", "MM", "MR", "BL", "BM", "BR"];
  let tlocSelected = "TR";

  let checked = false;
  let delivery_fault = false;
  let delivery_fault_assignment_number = 1;
  let delivery_fault_message = "";
  let bp_version = "fetching...";
  let api_version = "fetching...";
  let git_version = "fetching...";
  let nomad_allocation_id = "fetching...";
  let nomad_image = "fetching...";
  let enabled_features = "fetching...";
  let handleDeliveryFault = false;
  fetch("/internal/version")
    .then((e) => e.text())
    .then((text) => {
      let lines = text.split("\n");
      let version_line = lines[0];
      let api_line = lines[1];
      let git_line = lines[2];
      let nomad_line = lines[3];
      let image_line = lines[4];

      bp_version = version_line.split(":")[1];
      api_version = api_line.split(":")[1];
      git_version = git_line.split(":")[1];
      nomad_allocation_id = nomad_line.split(":")[1];
      nomad_image = image_line.split("=")[1];
      enabled_features = window.__boilerplate_features.join(" ");
    });

  async function fauxDeliveryFailureTest(
    input_pa_id,
    is_fault,
    delivery_fault_message
  ) {
    let data = {
      pa_id: input_pa_id,
      fault: is_fault,
      fault_message: delivery_fault_message ? delivery_fault_message : null,
    };
    let reply = await fetch(`/n/api/v1/assignment/deliveryfault`, {
      method: "POST",
      credentials: "include",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(data),
    });
    let replyAsObject = await reply.json();
    return replyAsObject;
  }
</script>

<h1>Internal Only</h1>
<div>
  <h3>Boilerplate version: {bp_version} with API {api_version}</h3>
  <p>Git: {git_version}</p>
  <p>Nomad: {nomad_image} / {nomad_allocation_id}</p>
  <p>Enabled features: {enabled_features}</p>
  <a href="/midlogin">
    <Button text="Midlogin (choose contact/requestor portal)" />
  </a>
  <br />
  <h4>Misc testing</h4>
  <span
    on:click={() => {
      showFatalError("shared", "no_recipient_account");
    }}
  >
    <Button text="Cause Fatal Error" />
  </span>
  <h4>Internal administration</h4>
  <span
    on:click={() => {
      window.location = "/internal/admin";
    }}
  >
    <Button text="Internal Admin (newco, etc.)" />
  </span>
  <span
    on:click={() => {
      window.location = "/internal/ff";
    }}
  >
    <Button text="feature flags" />
  </span>
  <span
    on:click={() => {
      window.location = "/internal/users";
    }}
  >
    <Button text="Impersonation" />
  </span>
  <span
    on:click={() => {
      window.location = "/internal/requestors";
    }}
  >
    <Button text="Requestor Revocation" />
  </span>
  <span
    on:click={() => {
      window.location = "/internal/tmplmover";
    }}
  >
    <Button text="Template Mover" />
  </span>
  <span
    on:click={() => {
      window.location = "/internal/stats";
    }}
  >
    <Button text="Internal Stats" />
  </span>
  <br />
  <span
    on:click={() => {
      window.location = "/internal/modco";
    }}
  >
    <Button text="Add User to Existing Company" />
  </span>
  <br />

  <span
    on:click={() => {
      fetch("/n/api/v1/internal/weeklydigest", {
        credentials: "include",
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        body: JSON.stringify({
          user_id: 0,
        }),
      }).then((reply) => {
        alert(
          `Sent if this is true: ${reply.ok}, if it's false there's a bug.`
        );
      });
    }}
  >
    <Button text="Force Send Weekly Digest" />
  </span>

  <div />
  <br />

  <div />
  <br />

  {#if $isToastVisible}
    <ToastBar />
  {/if}
  <label>
    <input type="checkbox" bind:checked />
    Click Here to show Toast Buttons
  </label>
  {#if checked}
    <select bind:value={ttypeSelected}>
      {#each toastType as ttype}
        <option value={ttype}>
          {ttype}
        </option>
      {/each}
    </select>

    <select bind:value={tlocSelected}>
      {#each toastLoc as tloc}
        <option value={tloc}>
          {tloc}
        </option>
      {/each}
    </select>

    <div
      class="show-bp-toast"
      on:click={() => {
        showToast("Toast Type Selected Toast!", 0, ttypeSelected, tlocSelected);
      }}
    >
      <Button text="Enter Variables above (lasts forever)" />
    </div>
    <br />
    <div />
    <div
      class="show-bp-toast"
      on:click={() => {
        showToast(
          "Toast Type Selected Toast!",
          2000,
          ttypeSelected,
          tlocSelected
        );
      }}
    >
      <Button text="Enter Variables above (lasts 3 Seconds)" />
    </div>
    <br />
    <div />

    <div
      class="show-bp-toast"
      on:click={() => {
        showToast("White Toast Example", 2000, "white", "MM");
      }}
    >
      <Button text="White Toast Example" />
    </div>
    <br />
    <div />

    <div
      class="show-bp-toast"
      on:click={() => {
        showToast("Did the Toast work? 3 Second wait", 3000, "error", "MM");
      }}
    >
      <Button text="Error toast with 3 Second Pause" />
    </div>
    <br />
    <div />
  {/if}
  {#if handleDeliveryFault}
    <EmailFaultDialog
      contact="TODO"
      on:close={() => {
        handleDeliveryFault = false;
      }}
    />
  {/if}
</div>
