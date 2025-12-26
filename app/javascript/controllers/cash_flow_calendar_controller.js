import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["day"];

  showDayDetails(event) {
    const date = event.currentTarget.dataset.date;

    // Use Turbo to load day details
    const turboFrame = document.querySelector("#day_details");
    if (turboFrame) {
      turboFrame.src = `/cash_flow/day/${date}`;
    }
  }

  highlightDay(event) {
    const day = event.currentTarget;
    day.classList.add("ring-2", "ring-primary");
  }

  unhighlightDay(event) {
    const day = event.currentTarget;
    day.classList.remove("ring-2", "ring-primary");
  }
}
