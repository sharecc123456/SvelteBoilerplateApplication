import { isMobile } from "Helpers/util";

const ACCOUNTID = "3c7e6865-1491-472e-b6ab-901fb5b7cb3d";
const TITLE = "Welcome to Boilerplate!";
const SUBTITLE = "Ask us anything in the chat window below 😊";
const onMobile = isMobile();

export const initializePaperCups = (user) => {
  window.Papercups = {
    config: {
      // Pass in your Papercups account token here after signing up
      accountId: ACCOUNTID,
      title: TITLE,
      subtitle: SUBTITLE,
      newMessagePlaceholder: "Start typing...",
      primaryColor: "#0693e3",
      // Optionally pass in a default greeting
      greeting: "Hi there! How can I help you?",
      // Optionally pass in metadata to identify the customer
      customer: { ...user },
      styles: { bottom: "60px" }, // cannot set styles here
      // Optionally specify the base URL
      baseUrl: "https://app.papercups.io",
      // Add this if you want to require the customer to enter
      // their email before being able to send you a message
      requireEmailUpfront: true,
      // Add this if you want to indicate when you/your agents
      // are online or offline to your customers
      showAgentAvailability: true,
      // Required help here as cannot cannot hook style during initailization
      styles: {
            chatContainer: {
              // left: 20,
              // right: 'auto',
              // bottom: 160,
              // maxHeight: 640,
            },
            toggleContainer: {
              // left: 20,
              // right: 'auto',
              bottom: 55,
              right: onMobile ? 10 : 20,
            },
            toggleButton: onMobile ? {
              width: "35px",
              height: "35px",
              padding: "8px"
            }: {},
          }
    },
  };

  // Create a dynamic script tag to add users dynamically
  var papercupsScript = document.createElement("script");
  papercupsScript.setAttribute("src", "https://app.papercups.io/widget.js");
  papercupsScript.setAttribute("type", "text/javascript");
  document.head.appendChild(papercupsScript);
};
