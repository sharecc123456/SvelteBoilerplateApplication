<script>
  import { addWhiteLabel } from "BoilerplateAPI/Company";
  import Modal from "Components/Modal.svelte";
  import TextField from "Components/TextField.svelte";
  import Button from "Atomic/Button.svelte";
  import { returnReviewItem } from "BoilerplateAPI/Review";

  export let logo = "";
  export let company_id = "";
  export let closeModal = () => {};

  let btnPressed = false;
  let error = false;

  async function addCompanyLogo() {
    btnPressed = true;
    error = false;
    try {
      const body = {
        logo,
        company_id,
      };
      await new Promise((r) => setTimeout(r, 1000));
      const res = await addWhiteLabel(body);
      if (res.msg == "OK") {
        closeModal();
        btnPressed = false;
        setTimeout(() => {
          window.location.reload();
        }, 200);
      } else {
        throw Error("Something happenned");
      }
    } catch (err) {
      console.error(err);
      error = true;
      btnPressed = false;
    }
  }
</script>

<Modal on:close={closeModal}>
  <div slot="header">
    <h4 style="margin: 0;line-height: 17px;font-weight: normal;">
      Logo Preview
    </h4>
  </div>

  <div class="return-modal">
    <img class="logo" src={"/n/api/v1/dproxy/" + logo} alt="logo" />
    <div on:click={addCompanyLogo}>
      <Button text="Save" disabled={btnPressed} />
    </div>
    {#if error}
      <span class="error">Sorry an error occured, please try again</span>
    {/if}
  </div>
</Modal>

<style>
  .return-modal {
    padding-top: 0.2rem;
  }

  .logo {
    max-width: 400px;
    height: auto;
    display: block;
    margin: 1rem auto;
  }

  .error {
    color: rgb(248, 47, 47);
  }
</style>
