<script>
  import { createEventDispatcher, onDestroy } from "svelte";
  import Button from "../atomic/Button.svelte";
  import TextField from "../components/TextField.svelte";
  import Dropdown from "./Dropdown.svelte";
  import { addTextSignature } from "../../api/User";
  import { checkIfReviewsPending } from "BoilerplateAPI/Review";
  import { onMount } from "svelte";
  import { showToast } from "../../helpers/ToastStorage.js";
  import { convertUTCToLocalDateStringWithTime } from "../../helpers/dateUtils";

  export let title = "Confirmation";
  export let question;
  export let details = null;
  export let yesText = "";
  export let noText;
  export let yesColor;
  export let noColor;
  
  // hide-button text, color, style 
  export let hideText;
  export let hideColor;
  export let hideStyle = "grid-area: b;"; //default position is center,out of > grid-template-areas: "a b c";
  export let hideButtonDisabled = false;

  export let showHideTooltip = false;
  export let tooltipHideMessage = "";
  export let noLeftAlign = false;
  export let esignConsent = false;
  export let textSignature = "";
  export let responseBoxEnable = null;
  export let dropdownEnable = null;
  export let dropdownValues = [];
  export let dropdownName = "";
  export let responseBoxEnable2 = null;
  export let responseBoxDemoText;
  export let responseBoxDemoText2;
  export let responseBoxText;
  export let responseBoxText2;
  export let popUp = false;
  export let popUpExtraClose = false; // add a full-width close button below the text.
  export let itemDisplay = null;
  export let requiresResponse = false;
  export let noIcon;
  export let yesIcon;
  export let hideX = false;
  export let textAreaEnable = null;
  export let textAreaDemoText;
  export let textAreaText;
  export let hyperLinks = null;
  export let hyperLinksColor;
  export let actions = null;
  export let actionsColor = null;
  export let checkBoxEnable = null;
  export let checkBoxText;
  export let CheckBoxStatus = false;
  export let contactInfo = null;
  export let recipient = false;

  export let showReminderInfo = false;
  export let lastReminderInfo = {};

  let errTxt = "";

  $: if (textSignature.trim().length === 0) {
    errTxt = "Signature cannot be empty.";
  } else if (textSignature.length > 40) {
    errTxt = "Name cannot be longer than 40 characters.";
  } else {
    errTxt = "";
  }

  $: if (!/^[a-zA-Z'\-,.‘’`\ ]+$/.test(textSignature)) {
    errTxt = "The name must not contain any special characters.";
  }

  const dispatch = createEventDispatcher();
  const close = () => {
    if (checkBoxEnable != null) {
      dispatch("close", CheckBoxStatus);
    } else {
      dispatch("close");
    }
  };

  export let guidePointsEnable = null;
  export let guidePoints;

  let modal;

  const handleCheckBox = () => {
    CheckBoxStatus = !CheckBoxStatus;
  };

  const handle_keydown = (e) => {
    if (e.key === "Escape") {
      close();
      return;
    }

    if (e.key === "Tab") {
      // trap focus
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
      submit();
      return;
    }
  };

  const previously_focused =
    typeof document !== "undefined" && document.activeElement;

  if (previously_focused) {
    onDestroy(() => {
      previously_focused.focus();
    });
  }

  function submit() {
    let textLength = textSignature.trim().length;
    if (esignConsent && textLength > 0 && textLength <= 25) {
      addTextSignature(textSignature.trim());
    }
    if (dropdownEnable != null) {
      dispatch("message", {
        text: selectedDropdownValue,
      });
    }
    if (responseBoxEnable != null) {
      if (responseBoxEnable2 != null) {
        dispatch("message", {
          text: responseBoxText,
          text2: responseBoxText2,
          CheckBoxStatus,
        });
        return;
      }
      dispatch("message", {
        text: responseBoxText,
        CheckBoxStatus,
      });
    } else if (textAreaEnable != null) {
      dispatch("message", {
        text: textAreaText,
      });
    } else {
      if (checkBoxEnable != null) {
        dispatch("yes", CheckBoxStatus);
      } else {
        dispatch("yes");
      }
    }
    if (checkBoxEnable != null) {
      hide();
    }
  }

  function hyperLinkRedirect({ url, callback }) {
    if (url) {
      window.location.hash = url;
    }
    dispatch("hide", {
      url,
      callback,
    });
  }

  function hide() {
    if (checkBoxEnable != null) {
      dispatch("hide", CheckBoxStatus);
    } else {
      dispatch("hide");
    }
  }

  function statusText(item) {
    switch (item.status) {
      case 0:
        return "Open, This has yet to be started by the Client";
      case 1:
        return "In Progress, This is in progress by the Client";
      case 2:
        return "Ready for review, You can click Review to get Started";
      case 3:
        return "Returned for updates, This was sent back for Updates";
      case 4:
        return "Completed, There is nothing more to do";
      case 5:
        return "Marked as Unavailable.";
      case 6:
        return "Marked as Unavailable.";
      default:
        return "UNKNOWN";
    }
  }

  let selectedDropdownValue;
  let reviewItemsPromise;

  onMount(async () => {
    if (window.__boilerplate_user_type == "requestor") {
      reviewItemsPromise = await checkIfReviewsPending();
    } else {
      reviewItemsPromise = Promise.resolve({
        exists: false,
        total_docs_count: 0,
        total_requests_count: 0,
      });
    }
  });

  function handleDropDown(ret) {
    selectedDropdownValue = ret;
  }
</script>

<svelte:window on:keydown={handle_keydown} />

<div class="modal-background" on:click={close} />

<div class="modal" role="dialog" aria-modal="true" bind:this={modal}>
  <div class="modal-content">
    <span class="modal-header">{title}</span>

    {#if question != null}
      <div class="modal-subheader">
        {question}
      </div>
    {/if}

    {#if details != null}
      <div class="modal-subheader" style="font-family: sans-serif;">
        {details}
      </div>
    {/if}

    {#if showReminderInfo}
      <div class="modal-subheader" style="font-family: sans-serif;">
        <div>
          Last Reminder: {convertUTCToLocalDateStringWithTime(
            lastReminderInfo.last_send_at
          ) || "N/A"}
        </div>
        <div>Sent by: {lastReminderInfo.send_by || "N/A"}</div>
        <div>Total send count: {lastReminderInfo.total_count || 0}</div>
      </div>
    {/if}

    {#if esignConsent}
      <br />
      <div class="input">
        <TextField bind:value={textSignature} text="Your name here..." />
        <span class="error-text">{errTxt}</span>
      </div>
    {/if}

    {#if itemDisplay != null}
      <div style="font-family: sans-serif;">
        <dl>
          <dt>Name</dt>
          <dd class="values">{itemDisplay.name}</dd>

          {#if itemDisplay.type != "task" && itemDisplay.description != null}
            <dt>Description</dt>
            <dd class="values">{itemDisplay.description}</dd>
          {/if}

          {#if itemDisplay.state != null && !recipient}
            <dt>Status</dt>
            <dd class="values">{statusText(itemDisplay.state)}</dd>
          {/if}

          <dt>{itemDisplay.type == "task" ? "Description" : "Other Info"}</dt>
          {#if itemDisplay.type == "file"}
            <dd class="values">
              This item is a File Request, the client will need to upload an
              item
            </dd>
          {/if}
          {#if itemDisplay.type == "data"}
            <dd class="values">
              This item is a Data Request, the client will need to enter in text
            </dd>
          {/if}
          {#if itemDisplay.type == "task" && itemDisplay.description}
            <dd class="values">
              {@html itemDisplay.description}
            </dd>
          {/if}

          {#if itemDisplay.type == "task" && itemDisplay.link && Object.keys(itemDisplay.link).length !== 0}
            <dt>Button link</dt>
            <dd class="values">
              <a target="_blank" href={itemDisplay.link.url}>
                {itemDisplay.link.url}
              </a>
            </dd>
          {/if}

          {#if itemDisplay.is_iac}
            <dd class="values">This item is an Online Fillable Item</dd>
          {:else if itemDisplay.is_iac == false}
            <dd class="values">This item is not an Online Fillable Item</dd>
          {/if}
          {#if itemDisplay.state?.status == 5 || itemDisplay.state?.status == 6}
            <dd class="values">
              Reason provided for being unavailable: <i
                >{itemDisplay.return_comments}</i
              >
            </dd>
          {/if}

          {#if itemDisplay.is_info}
            <dd class="values">
              This item is Informational only requiring only acknowledgement of
              the Client
            </dd>
          {:else if itemDisplay.is_rspec}
            <dd class="values">This item is a Contact Specific item</dd>
          {:else if itemDisplay.is_info == false}
            <dd class="values">This item is a Generic item</dd>
          {/if}
          {#if itemDisplay.is_manually_submitted}
            <dd class="values">
              This item was manually submitted by an admin.
            </dd>
          {/if}
          {#if itemDisplay.value && itemDisplay.type == "data"}
            <dt>Submitted value</dt>
            <dd
              on:copy={() => {
                showToast(`Copied to clipboard.`, 1000, "default", "MM");
              }}
              class="values"
              style="cursor: auto;"
            >
              {itemDisplay.value}
            </dd>
          {/if}
        </dl>
      </div>
    {/if}

    {#if guidePointsEnable != null}
      <ul>
        {#each guidePoints as Point}
          <li style="font-family: sans-serif; margin-top: 5px; font-size: 15px">
            {Point}
          </li>
        {/each}
      </ul>
    {/if}

    {#if contactInfo != null}
      <div class="contact-row modal-subheader">
        <div>
          <b>Email:</b>
          {contactInfo?.email}
        </div>
        <div>
          <b>Name:</b>
          {contactInfo?.name}
        </div>
        <div>
          <b>Company/ Org:</b>
          {contactInfo?.organization || contactInfo?.company || ""}
        </div>
      </div>
    {/if}

    {#if hyperLinks != null}
      <br />
      {#each hyperLinks as Link}
        <br />
        <span
          style="display: flex; justify-content: center;"
          on:click={Link?.disabled === true
            ? () => {}
            : () => hyperLinkRedirect(Link)}
        >
          <Button
            icon={Link?.icon}
            disabled={Link?.disabled === true || false}
            color={hyperLinksColor}
            text={Link?.title}
            halfWidth={true}
            iconLocation="floatLeft"
            floatLeft={true}
            reviewIcon={reviewItemsPromise?.exists &&
              Link?.title == "Review submissions"}
            style="display: flex; text-align: left;"
          />
        </span>
      {/each}
    {/if}

    {#if actions != null}
      <br />
      {#each actions as action}
        <br />
        <span
          style="display: flex; justify-content: center;"
          on:click={() => dispatch(action?.disabled ? {} : action.evt)}
        >
          <Button
            icon={action?.icon}
            color={actionsColor}
            text={action?.description}
            halfWidth={true}
            iconLocation="floatLeft"
            floatLeft={true}
            disabled={action?.disabled}
            style="display: flex; text-align: left;"
          />
        </span>
      {/each}
    {/if}

    {#if dropdownEnable != null}
      <br />
      <div class="input">
        <Dropdown
          text={dropdownName}
          clickHandler={(ret) => handleDropDown(ret)}
          elements={dropdownValues}
        />
        {#if selectedDropdownValue}
          <div style="padding-top: 7px;">{selectedDropdownValue}</div>
        {/if}
      </div>
    {/if}

    {#if responseBoxEnable != null}
      <br />
      <div class="input">
        <!-- <input type="text" id="inputBox" value={$responseBoxText}>    Causing errors -->
        <TextField
          focused={responseBoxEnable}
          bind:value={responseBoxText}
          text={responseBoxDemoText}
        />
      </div>
    {/if}

    {#if textAreaEnable != null}
      <br />
      <div class="input">
        <textarea
          maxlength="250"
          bind:value={textAreaText}
          text={textAreaDemoText}
        />
      </div>
      <span style="font-size: 12px;">Count: {textAreaText?.length}/250</span>
    {/if}

    {#if (checkBoxEnable != null && hyperLinks != null) || (checkBoxEnable != null && contactInfo != null)}
      <br />
      <label
        style="display: flex; justify-content: center; align-items: center;"
        class="checkbox"
      >
        <input
          type="checkbox"
          on:click={handleCheckBox}
          bind:checked={CheckBoxStatus}
        />
        <span class="pl-2">{checkBoxText}</span>
      </label>
    {:else if checkBoxEnable != null && hyperLinks == null}
      <br />
      <label class="checkbox">
        <input
          type="checkbox"
          on:click={handleCheckBox}
          bind:checked={CheckBoxStatus}
        />
        {checkBoxText}
      </label>
    {/if}

    {#if popUp && popUpExtraClose}
      <div
        style="width: 70%; padding-right: 15%; padding-left: 15%; padding-top: 2rem;"
        on:click={close}
      >
        <Button text="Close" />
      </div>
    {/if}

    {#if !popUp}
      <div
        class="submit-buttons"
        style={hideText && "grid-template-columns: repeat(3, minmax(0, 1fr))"}
        class:noLeftAlign
      >
        {#if noText}
          <span
            class="submit-child-buttons"
            style="grid-area: a;"
            on:click={close}
          >
            <Button color={noColor} text={noText} icon={noIcon} />
          </span>
        {/if}
        {#if hideText}
          <span class="submit-child-buttons" style={hideStyle} on:click={hide}>
            <Button
              color={hideColor}
              text={hideText}
              disabled={hideButtonDisabled}
              showTooltip={showHideTooltip}
              tooltipMessage={tooltipHideMessage}
            />
          </span>
        {/if}
        {#if yesText.length && hideText}
          <span
            class="tooltip submit-child-buttons"
            style="grid-area: c;"
            on:click={() => {
              if (responseBoxText?.toLowerCase() === responseBoxDemoText) {
                submit();
              }
            }}
          >
            <Button
              disabled={responseBoxText?.toLowerCase() !== responseBoxDemoText}
              color={yesColor}
              text={yesText}
            />
            {#if responseBoxText?.toLowerCase() !== responseBoxDemoText}
              <span class="tooltiptext">Type ‘delete’ above.</span>
            {/if}
          </span>
        {:else if yesText.length && !hideText && !esignConsent}
          <span
            class="submit-child-buttons"
            style="grid-area: b;"
            on:click={() => {
              if (
                !(responseBoxEnable2
                  ? requiresResponse &&
                    (responseBoxText?.trim() == "" ||
                      responseBoxText2?.trim() == "")
                  : requiresResponse && responseBoxText?.trim() == "")
              ) {
                submit();
              }
            }}
          >
            <Button
              color={yesColor}
              text={yesText}
              icon={yesIcon}
              disabled={responseBoxEnable2
                ? requiresResponse &&
                  (responseBoxText?.trim() == "" ||
                    responseBoxText2?.trim() == "")
                : requiresResponse && responseBoxText?.trim() == ""}
            />
          </span>
        {:else if yesText.length && !hideText && esignConsent}
          <span
            class="submit-child-buttons"
            style="grid-area: b;"
            on:click={() => {
              if (
                !(
                  textSignature.trim() == "" ||
                  (textSignature.length > 40) |
                    !/^[a-zA-Z'\-,.‘’`\ ]+$/.test(textSignature)
                )
              ) {
                submit();
              }
            }}
          >
            <Button
              color={yesColor}
              text={yesText}
              icon={yesIcon}
              disabled={textSignature.trim() == "" ||
                (textSignature.length > 40) |
                  !/^[a-zA-Z'\-,.‘’`\ ]+$/.test(textSignature)}
            />
          </span>
        {/if}
      </div>
    {/if}

    {#if responseBoxEnable2 != null}
      <br />
      <div class="input">
        <!-- <input type="text" id="inputBox" value={$responseBoxText}>    Causing errors -->
        <TextField bind:value={responseBoxText2} text={responseBoxDemoText2} />
      </div>
    {/if}

    <slot />

    <div on:click={close} class="modal-x" class:hideX>
      <i class="fas fa-times" />
    </div>
  </div>
</div>

<style>
  a {
    width: 250px;
    display: block;
    white-space: nowrap;
    text-overflow: ellipsis;
    overflow: hidden;
  }

  dt {
    font-weight: bold;
  }

  dl,
  dd {
    font-size: 0.9rem;
  }

  .hideX {
    display: none;
  }

  dd {
    margin-bottom: 1em;
  }

  textarea {
    width: 95%;
    height: 150px;
    padding: 12px 20px;
    box-sizing: border-box;
    border: 2px solid #ccc;
    border-radius: 4px;
    background-color: #f8f8f8;
    font-size: 16px;
  }
  .modal-subheader {
    font-family: sans-serif;
    padding-top: 1rem;
    font-style: normal;
    font-weight: 400;
    font-size: 15px;
    line-height: 24px;
    letter-spacing: 0.15px;
  }

  .submit-buttons {
    text-align: right;
    padding-top: 1rem;
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    grid-template-rows: minmax(0, 1fr);
    grid-template-areas: "a b c";
    column-gap: 1rem;
  }

  .submit-buttons.noLeftAlign {
    padding-top: 1rem;
  }
  .values {
    margin: 1px 0 1rem;
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
    font-family: sans-serif;
    font-style: normal;
    font-weight: 600;
    font-size: 24px;
    line-height: 34px;
    color: #2a2f34;
    padding-right: 18px;
  }

  .error-text {
    color: rgba(253, 0, 0, 0.719);
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 500;
    font-size: 14px;
    line-height: 21px;
    letter-spacing: 0.1px;
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
    border: 0.5px solid #33393c;
    z-index: 9999;
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

  .checkbox {
    font-family: sans-serif;
    font-size: 14px;
  }

  .tooltip {
    position: relative;
    display: inline-block;
  }
  .tooltip .tooltiptext {
    visibility: hidden;
    width: 100%;
    background-color: black;
    color: #fff;
    text-align: center;
    border-radius: 6px;
    padding: 6px 0;
    position: absolute;
    z-index: 1;
    bottom: 110%;
    left: 0%;
    right: 0%;
    font-size: 10px;
  }
  .tooltip .tooltiptext::after {
    content: "";
    position: absolute;
    top: 100%;
    left: 50%;
    margin-left: -5px;
    border-width: 5px;
    border-style: solid;
    border-color: black transparent transparent transparent;
  }
  .tooltip:hover .tooltiptext {
    visibility: visible;
  }

  .contact-row {
    width: 100%;
  }

  .pl-2 {
    padding-left: 0.5rem;
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
    .submit-buttons {
      display: grid;
    }
    .submit-child-buttons {
      padding-top: 10px;
    }
    .contact-row {
      flex-direction: column;
    }
  }
  @media only screen and (max-width: 425px) {
    .modal-header {
      font-size: 14px;
    }
  }
</style>
