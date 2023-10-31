<script>
  import ReviewMobileView from "../../components/ReviewHelpers/ReviewMobileView.svelte";
  import Button from "../../atomic/Button.svelte";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import BackgroundPageHeader from "../../components/BackgroundPageHeader.svelte";
  import {
    getReviewsPaginated,
    acceptReviewItem,
    acceptAllReviewItem,
    SORT_FIELDS,
  } from "BoilerplateAPI/Review";
  import RequestorHeaderNew from "../../components/RequestorHeaderNew.svelte";
  import EmptyDefault from "../../util/EmptyDefault.svelte";
  import Loader from "../../components/Loader.svelte";
  import TablePager from "Components/TablePager.svelte";
  import TableSorter from "Components/TableSorter.svelte";
  import { onMount } from "svelte";
  import { getOnlyDate, convertTime } from "Helpers/util";
  import { featureEnabled } from "Helpers/Features";
  import ConfirmationDialog from "../../components/ConfirmationDialog.svelte";
  import Tag from "../../atomic/Tag.svelte";

  let scrollY;

  // pagination stuff
  let page = 1;
  let totalPages = 1;
  let reviewsData = [];
  let hasNext = false;
  let loading = true;
  let count = 0;
  let sort = SORT_FIELDS.DATE_SUBMITTED;
  let sortDirection = "desc";
  let search_value = "";
  let showAcceptAllDialog = false;

  const loadReviewData = async (targetPage = 1) => {
    loading = true;
    try {
      const params = {
        page: targetPage,
        search: search_value || "",
        sort,
        sort_direction: sortDirection,
      };

      const res = await getReviewsPaginated(params);

      console.log(res);

      page = res.page;
      reviewsData = res.data;
      totalPages = res.total_pages;
      hasNext = res.has_next;
      count = res.count;
      return res;
    } catch (err) {
      console.error(err);
      page = 1;
      totalPages = 1;
      reviewsData = [];
      hasNext = false;
      count = 0;
      return { data: [], page: 1, total_pages: 1, has_next: false };
    } finally {
      loading = false;
    }
  };

  const handleServerSearch = () => {
    refreshReviewPromise();
  };

  const sortReviewData = (_targetSort = SORT_FIELDS.DATE_SUBMITTED) => {
    // direction change
    if (sort === _targetSort)
      sortDirection = sortDirection === "asc" ? "desc" : "asc";
    else {
      // sort change
      sort = _targetSort;
      sortDirection = "asc";
    }

    refreshReviewPromise();
  };

  let reviewItemsPromise = loadReviewData();
  const refreshReviewPromise = (targetPage = 1) => {
    reviewItemsPromise = loadReviewData(targetPage);
  };
  let totalReviewCount = 0;

  let getReviewItemsCount = async () => {
    let reviewItems = await reviewItemsPromise;

    totalReviewCount = reviewItems.data.reduce(
      (previousValue, currentObj) =>
        previousValue +
          (currentObj?.documents.length + currentObj?.requests.length) || 0,
      0
    );
  };

  const getTime = (date) => {
    let [onlyDate, time, meridian] = date.split(" ");
    if (time && meridian) {
      return `${convertTime(onlyDate, `${time} ${meridian}`)}`;
    } else {
      return "";
    }
  };

  // Accept reviews
  const acceptAll = (data) => {
    showAcceptAllDialog = false;
    acceptAllReviewItem(data).then((data) => {
      window.location.reload();
    });
  };

  onMount(() => getReviewItemsCount());
  // pagination stuff
</script>

<svelte:window bind:scrollY />

<BackgroundPageHeader {scrollY} />

<div class="page-header">
  <RequestorHeaderNew
    title="Review"
    icon="glasses"
    bind:search_value
    searchPlaceholder="Search Review"
    headerBtn={totalReviewCount > 0 && featureEnabled("review_accept_all")}
    showMobileActionBtn="true"
    btnText="Accept all"
    btnColor="secondary"
    btnAction={() => {
      showAcceptAllDialog = true;
    }}
    {handleServerSearch}
    contactCount={totalReviewCount}
    loadAssignment={false}
  />
</div>

<div class="container">
  <div class="table">
    {#await reviewItemsPromise}
      <span class="loader-container">
        <Loader loading />
      </span>
    {:then { data: reviewItems, page, total_pages: totalPages, has_next }}
      {#if reviewItems.length}
        <div class="tr th desktop-only">
          <div style="padding-left: 1rem" class="td">
            <div
              class="sortable {sort == SORT_FIELDS.RECIPIENT_NAME
                ? 'selectedBorder'
                : ''}"
              style="display: flex;
                  align-items: center;"
              on:click={() => {
                sortReviewData(SORT_FIELDS.RECIPIENT_NAME);
              }}
            >
              &nbsp; Contact &nbsp;
              <TableSorter
                column={SORT_FIELDS.RECIPIENT_NAME}
                {sort}
                {sortDirection}
              />
              &nbsp;
            </div>
            <div
              class="sortable {sort == SORT_FIELDS.RECIPIENT_ORG
                ? 'selectedBorder'
                : ''}"
              style="display: flex;
                  align-items: center;"
              on:click={() => {
                sortReviewData(SORT_FIELDS.RECIPIENT_ORG);
              }}
            >
              &nbsp; Org &nbsp;
              <TableSorter
                column={SORT_FIELDS.RECIPIENT_ORG}
                {sort}
                {sortDirection}
              />
              &nbsp;
            </div>
          </div>
          <div class="td chklist-flex-grow">
            <div
              class="sortable {sort == SORT_FIELDS.CHECKLIST_NAME
                ? 'selectedBorder'
                : ''}"
              style="display: flex;
                  align-items: center;"
              on:click={() => {
                sortReviewData(SORT_FIELDS.CHECKLIST_NAME);
              }}
            >
              &nbsp; Checklist &nbsp;
              <TableSorter
                column={SORT_FIELDS.CHECKLIST_NAME}
                {sort}
                {sortDirection}
              />
              &nbsp;
            </div>
          </div>
          <div class="td status desktop">
            <div
              class="sortable {sort == SORT_FIELDS.STATUS
                ? 'selectedBorder'
                : ''}"
              style="display: flex;
                  align-items: center;"
              on:click={() => {
                sortReviewData(SORT_FIELDS.STATUS);
              }}
            >
              &nbsp; Status &nbsp;
              <TableSorter column={SORT_FIELDS.STATUS} {sort} {sortDirection} />
              &nbsp;
            </div>
            <div
              class="sortable {sort == SORT_FIELDS.DATE_SUBMITTED
                ? 'selectedBorder'
                : ''}"
              style="display: flex;
                  align-items: center;"
              on:click={() => {
                sortReviewData(SORT_FIELDS.DATE_SUBMITTED);
              }}
            >
              &nbsp; Date &nbsp;
              <TableSorter
                column={SORT_FIELDS.DATE_SUBMITTED}
                {sort}
                {sortDirection}
              />
              &nbsp;
            </div>
            <span class="empty-span" />
          </div>
          <div class="td action ">Actions</div>
        </div>
        {#each reviewItems as item}
          <span class="desktop-only">
            <div
              on:click={() =>
                (window.location.hash = `#review/${item.contents_id}`)}
              class="tr"
            >
              <div class="td">
                <div class="twoline">
                  <div class="title truncate">
                    {item.recipient.name}
                  </div>
                  <div class="subtitle truncate">
                    {item.recipient.company
                      ? `(${item.recipient.company})`
                      : ""}
                  </div>
                  {#if item.recipient.email}
                    <div class="subtitle truncate">{item.recipient.email}</div>
                  {/if}
                  {#if item.tags}
                    <ul class="reset-style">
                      {#each item.tags as tag}
                        <Tag isSmall={true} {tag} allowDeleteTags={false} />
                      {/each}
                    </ul>
                  {/if}
                </div>
              </div>
              <div class="td chklist-flex-grow">
                <div class="twoline">
                  <div class="title truncate">
                    {item.checklist.name}
                  </div>
                  <div class="subtitle">{item.checklist.description}</div>
                  {#if item.requestor_description}
                    <span
                      class="subtitle review-checklist__reference tooltip ref"
                      title={item.requestor_description}
                    >
                      [{item.requestor_description}]
                    </span>
                  {/if}
                  {#if item.recipient_description}
                    <span
                      class="subtitle review-checklist__reference tooltip ref"
                      title={item.recipient_description}
                    >
                      [{item.recipient_description}]
                    </span>
                  {/if}
                </div>
              </div>
              <div class="td">
                <div class="submission-status">
                  <div class="icon">
                    <FAIcon icon="exclamation-circle" iconStyle="regular" />
                  </div>
                  <div class="twoline-small">
                    <div class="title truncate">
                      {item.fully_submitted ? "Full" : " Partial "} Submission
                    </div>
                    <div class="subtitle truncate">
                      {getOnlyDate(item.submitted)}
                      {getTime(item.submitted)}
                    </div>
                  </div>
                </div>
              </div>
              <div class="td action">
                <a href={`#review/${item.contents_id}`}>
                  <Button text="Review" />
                </a>
              </div>
            </div>
          </span>

          <span class="mobile-only">
            <ReviewMobileView
              data={item}
              submitted_date={getOnlyDate(item.submitted)}
              submitted_time={getTime(item.submitted)}
            />
          </span>
        {/each}
        <TablePager
          {page}
          {totalPages}
          handleNextPage={() => {
            if (has_next) refreshReviewPromise(page + 1);
          }}
          handlePrevPage={() => {
            if (page > 1) refreshReviewPromise(page - 1);
          }}
        />
      {:else if search_value != "" && !reviewItems.length}
        <EmptyDefault
          cancelButton={true}
          defaultHeader="No Search results!"
          defaultMessage="No results for this search on this screen"
          on:close={() => {
            search_value = "";
            loadReviewData();
          }}
        />
      {:else}
        <EmptyDefault
          defaultHeader="Nothing to review!"
          defaultMessage="Looks like you are all caught up on reviews! Once a new review is available, you will see a notification next to the review tab"
        />
      {/if}
    {:catch error}
      <EmptyDefault
        defaultHeader="Oh uh, something went wrong!"
        defaultMessage="Try refreshing the page through your browser navigation bar above. If that doesn’t work, please contact support@boilerplate.co thank you!"
        error
      />
    {/await}
  </div>
</div>

{#if showAcceptAllDialog}
  <ConfirmationDialog
    title="Attention!"
    question={`Are you sure you want to accept all? This will bypass individual reviews of these items and can’t be undone. Note that items requiring countersignatures will be skipped.`}
    yesText="Yes, Accept All"
    noText="Cancel"
    yesColor="danger"
    noColor="gray"
    on:yes={() => {
      console.log("accept all");
      acceptAll(reviewsData);
    }}
    on:close={() => {
      showAcceptAllDialog = false;
    }}
  />
{/if}

<style>
  .selectedBorder {
    border: 1px solid #76808b;
    border-radius: 5px;
  }

  .reset-style {
    margin: 0;
    padding: 0;
  }

  /* submission-status */
  .submission-status {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
  }
  .page-header {
    position: sticky;
    top: 10px;
    z-index: 12;
    background: #fcfdff;
  }

  .submission-status > .icon {
    padding-right: 0.5rem;
  }

  .review-checklist__reference {
    cursor: pointer;
    width: 200px;
    display: inline-block;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    vertical-align: middle;
  }

  .tooltip {
    position: relative;
  }

  .tooltip:hover {
    content: attr(title);
  }

  .twoline-small {
    display: flex;
    flex-flow: column nowrap;
  }

  .subtitle {
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 24px;
    color: #76808b;
  }

  /* twoline */
  .twoline {
    display: flex;
    flex-flow: column nowrap;
    width: 90%;
  }

  .truncate {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .sortable {
    cursor: pointer;
    left: 6px;
    /* top: 2px; */
    position: relative;
    color: #76808b;
  }

  /* table */
  .table {
    display: flex;
    flex-flow: column nowrap;
    flex: 1 1 auto;
    margin: 0 auto;
  }

  .th {
    display: none;
  }

  .th > .td {
    white-space: normal;
    justify-content: left;
    font-weight: 600;
    font-size: 14px;
    line-height: 16px;

    height: 37px;
    align-items: center;
  }

  .tr {
    width: 100%;
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
  }

  .tr:not(.th) {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;
    padding-top: 1rem;
    padding-bottom: 1rem;
    margin-bottom: 1rem;
    cursor: pointer;
  }

  .tr > .td:first-child {
    padding-left: 2rem;
  }

  .td.status {
    display: flex;
    align-items: center;
  }

  .td {
    display: flex;
    flex-flow: row nowrap;
    flex-grow: 2;
    flex-basis: 0;
    min-width: 0px;
  }
  .ref {
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 24px;
    color: #76808b;
  }
  .tr.th {
    position: sticky;
    background-color: #f8fafd;
    top: 100px;
    z-index: 10;
    color: #76808b;
  }

  a {
    text-decoration: none;
  }
  .mobile-only {
    display: none;
  }

  .title {
    font-style: normal;
    font-weight: 500;
    font-size: 14px;
    line-height: 21px;
    letter-spacing: 0.1px;
    color: #2a2f34;
  }

  .subtitle {
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 24px;
    color: #76808b;
  }

  .action {
    justify-content: center !important;
  }

  .chklist-flex-grow {
    flex-grow: 3;
  }

  @media only screen and (max-width: 920px) {
    .desktop {
      display: none !important;
    }
  }
  @media only screen and (max-width: 767px) {
    .tr.th {
      top: 67px;
    }
    .desktop-only {
      display: none;
    }
    .mobile-only {
      display: block;
    }
    .loader-container {
      height: 70vh;
      display: flex;
      justify-content: center;
      align-items: center;
    }

    .chklist-flex-grow {
      flex-grow: 1;
    }
  }
</style>
