<script>
  import { start_search } from './../../store';
  import Button from "../atomic/Button.svelte";
  import Avatar from "../atomic/Avatar.svelte";

  import UploadFileModal from "../modals/UploadFileModal.svelte";
  import SearchBar from "./SearchBar.svelte";

  export let search_value;
  //props
  export let heading;
  export let btnText;
  export let headerBtn;
  export let withAvatar = null;
  export let btnAction;
  export let searchPlaceholder;
  let showUploadModal = false;
  async function processNewTemplate(evt) {
    let detail = evt.detail;
    let fd = new FormData();
    fd.append("name", detail.name);
    fd.append("upload", detail.file);

    let reply = await fetch(`/n/api/v1/template`, {
      method: "POST",
      credentials: "include",
      body: fd,
    });

    console.log(reply);
    if (reply.ok) {
      let jsonReply = await reply.json();
      window.location.hash = `#template/${jsonReply.id}`;
    } else {
      alert("Something went wrong while uploading this file");
    }
  }
</script>

  <span class="mobile-searchbar { $start_search ? 'active-searchbar' : ''}">
    <SearchBar bind:search_value {searchPlaceholder} />
  </span>

<section>
  <p class="templates-mainline">
    <span class="desktop-searchbar">
      <SearchBar bind:search_value {searchPlaceholder} />
    </span>
    {#if false && withAvatar != null}
      <div class="avatar">
        <Avatar
          avatarName={withAvatar.name}
          avatarCompany={withAvatar.organization}
          onMain={withAvatar.onMain}
        />
      </div>
    {/if}
  </p>
  <div class="templates-subline">
    <div class="item templates">
      <h3>{heading}</h3>
    </div>
    {#if headerBtn}
      <div class="item upload">
        <span on:click={btnAction}>
          <Button color="secondary" text={btnText} />
        </span>
      </div>
    {/if}
  </div>
</section>

{#if showUploadModal}
  <UploadFileModal
    multiple={false}
    specializedFor="newTemplate"
    on:done={processNewTemplate}
    on:close={() => {
      showUploadModal = false;
    }}
  />
{/if}

<style>
  section {
    position: sticky;
    top: 0;
    width: 100%;
    z-index: 10;
    background: #f8fafd;
  }

  .desktop-searchbar{
    display: block;
  }

  h3 {
    font-family: "Lato", sans-serif;
  }
  .avatar {
    padding-left: 1rem;
    text-align: right;
    vertical-align: middle;
    padding-right: 4rem;
    align-items: center;
    align-content: center;
    width: 100%;
  }

  .templates-mainline {
    padding-top: 1em;
    display: flex;
    flex-flow: row nowrap;
    justify-content: center;
    width: 80%;
    margin: 0 auto;
  }

  .templates-subline {
    display: grid;
    grid-template-columns: 1fr;
    justify-items: center;
    align-items: center;
    width: 100%;
  }
  .templates-subline > .item > h3 {
    font-style: normal;
    font-weight: bold;
    font-size: 28px;
    line-height: 34px;
    color: #2a2f34;
  }

  .item.upload {
    margin-bottom: 1rem;
  }

  .mobile-searchbar{
    display: none;
  }
  @media only screen and (min-width: 640px) {
    .templates-subline {
      grid-template-columns: repeat(2, 1fr);
    }
    .item.upload {
      justify-self: end;
      padding-right: 1rem;
      margin-bottom: initial;
    }
    .item.templates {
      justify-self: start;
    }
  }

  @media only screen and (max-width: 767px) {
    section{
      display: none;
    }
    .mobile-searchbar{
      display: block;
      position: fixed;
      z-index: 0;
      top: 18px;
      left: 52px;
      height: 2.5rem;
      width: 0;
      transition: width 0.3s ease;
    }
    .active-searchbar{
      width: calc(100% - 150px);
      z-index: 999;
    }

    .desktop-searchbar{
      display: none;
    }
  }
</style>
