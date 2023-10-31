<script>
  import { createEventDispatcher, onMount } from "svelte";
  import FAIcon from "../atomic/FAIcon.svelte";
  import Button from "../atomic/Button.svelte";
  import { getUserRetrieveLink } from "BoilerplateAPI/User";
  import { getRecipient } from "BoilerplateAPI/Recipient";

  export let fault_message = "";
  export let email;
  export let user_name;
  export let company;
  export let recipient_id;
  let recipient;
  let user_id;
  let cleared = false;

  let modal;
  let ExpandOptions = false;
  let ExpandReason = false;

  let RetrieveLink = false;
  let ExpandRetrieveLink = false;
  let link = "";

  const dispatch = createEventDispatcher();
  const close = () => {
    dispatch("close");
  };

  const handle_keydown = (e) => {
    if (e.key === "Escape") {
      close();
      return;
    }

    if (e.key === "Tab") {
      const nodes = modal.querySelectorAll("*");
      const tabbable = Array.from(nodes).filter((n) => n.tabIndex >= 0);

      let index = tabbable.indexOf(document.activeElement);
      if (index === -1 && e.shiftKey) index = 0;

      index += tabbable.length + (e.shiftKey ? -1 : 1);
      index %= tabbable.length;

      tabbable[index].focus();
      e.preventDefault();
    }

    if (e.key === "Enter") {
      close();
      return;
    }
  };

  onMount(async () => {
    recipient = await getRecipient(recipient_id);
    user_id = recipient.user_id;
    console.log(user_id);
    let reply = await getUserRetrieveLink(user_id);
    if (reply.ok) {
      let res = await reply.json();
      link = res.link;
    } else {
      link = "error";
    }
  });

  async function clearDeliveryFault(user_id) {
    let data = {
      user_id: user_id,
    };
    let reply = await fetch(`/n/api/v1/assignment/cleardeliveryfault`, {
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

<svelte:window on:keydown={handle_keydown} />

<div class="modal-background" on:click={close} />

<div class="modal" role="dialog" aria-modal="true" bind:this={modal}>
  <div class="modal-content">
    {#if !RetrieveLink}
      <span class="modal-header">What is a 'Delivery Fault'?</span>
      <div
        class="modal-subheader"
        style="font-family: 'Nunito', sans-serif; font-weight: bold;"
      >
        Unfortunely the email attached to this contact below has denied our
        email attempt.
      </div>
      <br />
      <span>
        <div>Email: <b>{email}</b></div>
        <div>Name: <b>{user_name}</b></div>
        <div>Company: <b>{company}</b></div>
      </span>

      {#if fault_message.length}
        <br />
        <div
          class="modal-subheader"
          style="font-family: 'Nunito', sans-serif; font-weight: bold;"
        >
          Here is some extra information we got from the email delivery attempt:
        </div>
        <div class="modal-subheader" style="font-family: 'Nunito', sans-serif;">
          {fault_message}
        </div>
      {/if}
      <br />
      <span
        on:click={() => {
          if (ExpandReason) {
            ExpandReason = false;
          } else {
            ExpandReason = true;
            ExpandOptions = false;
          }
        }}
      >
        <button
          style={ExpandReason
            ? "border-bottom-left-radius: 0px; border-bottom-right-radius: 0px;"
            : ""}
        >
          {#if ExpandReason}
            <FAIcon icon="minus" iconSize="large" floatLeft={true} />
          {:else}
            <FAIcon icon="plus" iconSize="large" floatLeft={true} />
          {/if}

          <span style="font-family: 'Nunito', sans-serif; text-align: right; "
            >Why did this happen?</span
          >
        </button>
      </span>
      {#if ExpandReason}
        <div
          class="modal-button-dropdown"
          style="font-family: 'Nunito', sans-serif;"
        >
          Here are the most common email delivery issues:
          <ul>
            <li>Spelling error</li>
            <li>Mailbox is disabled or full</li>
            <li>Mail is being marked as spam</li>
          </ul>
        </div>
      {/if}
      <br />
      <span
        on:click={() => {
          if (ExpandOptions) {
            ExpandOptions = false;
          } else {
            ExpandOptions = true;
            ExpandReason = false;
          }
        }}
      >
        <button
          style={ExpandOptions
            ? "border-bottom-left-radius: 0px; border-bottom-right-radius: 0px;"
            : ""}
        >
          {#if ExpandOptions}
            <FAIcon icon="minus" iconSize="large" floatLeft={true} />
          {:else}
            <FAIcon icon="plus" iconSize="large" floatLeft={true} />
          {/if}

          <span style="font-family: 'Nunito', sans-serif; text-align: right; "
            >What can you do to fix this?</span
          >
        </button>
      </span>
      {#if ExpandOptions}
        <div
          class="modal-button-dropdown"
          style="font-family: 'Nunito', sans-serif;"
        >
          There are a few options that may resolve future contact with this
          recipient
          <ul>
            <li>
              Verify The email is correct - Update this in the contact page
            </li>
            <li>
              Ask the contact to check their spam folder - Mark as not spam
            </li>
            <li>Manually send the link - Do not click it yourself!</li>
            <li>Update their email to send to an alternative email</li>
            <li>The contact adds @boilerplate.co to their allow list</li>
          </ul>
        </div>
      {/if}
      <br />
      <span style="display: flex; justify-content: center;">
        <span
          on:click={() => {
            RetrieveLink = true;
          }}
        >
          <Button
            style="left: -2rem; position: relative;"
            color="white"
            text="Retrieve link"
            disabled={false}
          />
        </span>
        <br />
        <span
          on:click={() => {
            window.location.hash = `#recipient/${recipient_id}/details/user`;
            window.location.reload();
          }}
        >
          <Button
            style="left: 2rem; position: relative;"
            color="secondary"
            text="Update contact info"
          />
        </span>
      </span>
      <div on:click={close} class="modal-x">
        <i class="fas fa-times" />
      </div>
    {:else}
      <span class="modal-header">One time use link</span>
      <div
        class="modal-subheader"
        style="font-family: 'Nunito', sans-serif; font-weight: bold;"
      />
      <span>
        <div>
          The link below is a one time use link, from here you can copy and
          paste this to your contact directly.
        </div>
        <br />
        <div>
          Once this link is shown or copied to clipboard, the 'Delivery Fault'
          status will be removed, this means the delivery of this link is in
          your hands.
        </div>
        <br />
        <div>Do not use this link yourself.</div>
      </span>
      <br />
      <span
        on:click={() => {
          if (ExpandRetrieveLink) {
            ExpandRetrieveLink = false;
          } else {
            if (!cleared) {
              clearDeliveryFault(recipient_id);
              cleared = true;
            }
            ExpandRetrieveLink = true;
          }
        }}
      >
        <button
          style={ExpandRetrieveLink
            ? "border-bottom-left-radius: 0px; border-bottom-right-radius: 0px;"
            : ""}
        >
          {#if ExpandRetrieveLink}
            <FAIcon icon="minus" iconSize="large" floatLeft={true} />
          {:else}
            <FAIcon icon="plus" iconSize="large" floatLeft={true} />
          {/if}

          <span style="font-family: 'Nunito', sans-serif; text-align: right; "
            >Show one time use link</span
          >
        </button>
      </span>
      {#if ExpandRetrieveLink}
        <div
          class="modal-button-dropdown"
          style="font-family: 'Nunito', sans-serif; word-wrap: break-word;"
        >
          {link}
        </div>
      {/if}
      <br />
      <span style="display: flex; justify-content: center;">
        <span
          on:click={() => {
            RetrieveLink = false;
          }}
        >
          <Button
            style="left: -2rem; position: relative;"
            color="white"
            text="Go back"
          />
        </span>
        <span
          on:click={() => {
            clearDeliveryFault(recipient_id);
            navigator.clipboard.writeText(link);
            alert("Copied to clipboard");
            close();
            window.location.reload();
          }}
        >
          <Button
            style="left: 2rem; position: relative;"
            color="secondary"
            text="Copy link and close"
          />
        </span>
      </span>
    {/if}
    <div on:click={close} class="modal-x">
      <i class="fas fa-times" />
    </div>
  </div>
</div>

<style>
  button {
    display: block;
    width: 100%;
    border-style: solid;
    border-radius: 4px;
    cursor: pointer;
    padding: 0.5rem 1.5rem;

    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 500;
    font-size: 14px;
    line-height: 16px;
    max-height: 40px;
    /* identical to box height, or 114% */
    text-align: center;
    text-decoration: none;
    letter-spacing: 0.02em;
    text-transform: none;
    white-space: nowrap;
    color: #000000;
    background: #ffffff;
    border-color: #4a5157;

    filter: drop-shadow(0px 3px 4px rgba(46, 56, 77, 0.12));
  }

  .modal-subheader {
    font-family: "Nunito", sans-serif;
    padding-top: 1rem;
    font-style: normal;
    font-weight: 400;
    font-size: 15px;
    line-height: 24px;
    letter-spacing: 0.15px;
  }

  .modal-button-dropdown {
    border: 2px solid #4a5157;
    border-top: none;
    border-bottom-left-radius: 10px;
    border-bottom-right-radius: 10px;
    box-sizing: border-box;
    font-family: "Nunito", sans-serif;
    padding-top: 1rem;
    font-style: normal;
    font-weight: 400;
    font-size: 15px;
    line-height: 20px;
    margin-bottom: 0rem;
    padding: 0.5rem;
  }

  .modal-background {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.3);
    z-index: 49;
  }

  .modal-header {
    margin-block-start: 0;
    margin-block-end: 1rem;
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 600;
    font-size: 24px;
    line-height: 34px;
    color: #2a2f34;
    padding-right: 18px;
  }

  .modal {
    position: fixed;
    left: 50%;
    top: 55%;
    width: calc(100vw - 4em);
    max-width: 33em;
    max-height: calc(100vh - 10em);
    overflow: auto;
    transform: translate(-50%, -50%);
    padding: 1em;
    background: #ffffff;
    border-radius: 10px;
    z-index: 999;
  }

  .modal-content {
    padding-left: 1rem;
    padding-right: 1rem;
  }

  .modal-x {
    position: absolute;
    font-size: 24px;
    left: calc(100% - 1.3rem);
    top: 0.1rem;
    cursor: pointer;
  }

  @media only screen and (max-width: 786px) {
    .modal-header {
      font-size: 18px;
    }
    .modal-content {
      padding-left: 0rem;
      padding-right: 0rem;
      padding-bottom: 1rem;
      overflow-x: hidden;
    }

    .modal-x {
      font-size: 18px;
      left: calc(100% - 1.1rem);
      top: 0.2rem;
      cursor: pointer;
    }
  }
  @media only screen and (max-width: 425px) {
    .modal-header {
      font-size: 14px;
    }
  }
</style>
