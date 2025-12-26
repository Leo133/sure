import { Controller } from "@hotwired/stimulus";
import * as d3 from "d3";

const parseLocalDate = d3.timeParse("%Y-%m-%d");

export default class extends Controller {
  static targets = ["canvas"];
  static values = {
    data: Array,
  };

  _d3SvgMemo = null;
  _d3GroupMemo = null;
  _d3Tooltip = null;
  _d3InitialContainerWidth = 0;
  _d3InitialContainerHeight = 0;
  _resizeObserver = null;

  connect() {
    this._install();
    document.addEventListener("turbo:load", this._reinstall);
    this._setupResizeObserver();
  }

  disconnect() {
    this._teardown();
    document.removeEventListener("turbo:load", this._reinstall);
    this._resizeObserver?.disconnect();
  }

  _reinstall = () => {
    this._teardown();
    this._install();
  };

  _teardown() {
    this._d3SvgMemo = null;
    this._d3GroupMemo = null;
    this._d3Tooltip = null;

    this._d3Container.selectAll("*").remove();
  }

  _install() {
    this._rememberInitialContainerSize();
    this._draw();
  }

  _rememberInitialContainerSize() {
    this._d3InitialContainerWidth = this._d3Container.node().clientWidth;
    this._d3InitialContainerHeight = this._d3Container.node().clientHeight;
  }

  _draw() {
    const minWidth = 50;
    const minHeight = 50;

    if (
      this._d3ContainerWidth < minWidth ||
      this._d3ContainerHeight < minHeight
    ) {
      return;
    }

    if (this._normalizedData.length < 2) {
      this._drawEmpty();
    } else {
      this._drawChart();
    }
  }

  _drawEmpty() {
    this._d3Svg.selectAll(".tick").remove();
    this._d3Svg.selectAll(".domain").remove();

    this._d3Svg
      .append("line")
      .attr("x1", this._d3InitialContainerWidth / 2)
      .attr("y1", 0)
      .attr("x2", this._d3InitialContainerWidth / 2)
      .attr("y2", this._d3InitialContainerHeight)
      .attr("stroke", "var(--color-gray-300)")
      .attr("stroke-dasharray", "4, 4");

    this._d3Svg
      .append("circle")
      .attr("cx", this._d3InitialContainerWidth / 2)
      .attr("cy", this._d3InitialContainerHeight / 2)
      .attr("r", 4)
      .attr("class", "fg-subdued")
      .style("fill", "currentColor");
  }

  _drawChart() {
    this._drawZeroLine();
    this._drawConfidenceArea();
    this._drawBalanceLine();
    this._drawXAxisLabels();
    this._drawTooltip();
    this._trackMouseForShowingTooltip();
  }

  _drawZeroLine() {
    const zeroY = this._d3YScale(0);

    if (zeroY >= 0 && zeroY <= this._d3ContainerHeight) {
      this._d3Group
        .append("line")
        .attr("x1", 0)
        .attr("y1", zeroY)
        .attr("x2", this._d3ContainerWidth)
        .attr("y2", zeroY)
        .attr("stroke", "var(--color-destructive)")
        .attr("stroke-width", 1)
        .attr("stroke-dasharray", "4, 4")
        .attr("opacity", 0.5);
    }
  }

  _drawConfidenceArea() {
    // Draw a gradient area showing decreasing confidence over time
    const gradient = this._d3Svg
      .append("defs")
      .append("linearGradient")
      .attr("id", `${this.element.id}-confidence-gradient`)
      .attr("x1", "0%")
      .attr("x2", "100%");

    gradient
      .append("stop")
      .attr("offset", "0%")
      .attr("stop-color", "var(--color-info)")
      .attr("stop-opacity", 0.1);

    gradient
      .append("stop")
      .attr("offset", "100%")
      .attr("stop-color", "var(--color-info)")
      .attr("stop-opacity", 0.02);

    // Draw area under the line
    const area = d3
      .area()
      .x((d) => this._d3XScale(d.date))
      .y0(this._d3ContainerHeight)
      .y1((d) => this._d3YScale(d.balance));

    this._d3Group
      .append("path")
      .datum(this._normalizedData)
      .attr("fill", `url(#${this.element.id}-confidence-gradient)`)
      .attr("d", area);
  }

  _drawBalanceLine() {
    // Create gradient for the line (blue to gray showing confidence decay)
    const lineGradient = this._d3Svg
      .append("defs")
      .append("linearGradient")
      .attr("id", `${this.element.id}-line-gradient`)
      .attr("gradientUnits", "userSpaceOnUse")
      .attr("x1", this._d3XScale.range()[0])
      .attr("x2", this._d3XScale.range()[1]);

    lineGradient
      .append("stop")
      .attr("offset", "0%")
      .attr("stop-color", "var(--color-info)");

    lineGradient
      .append("stop")
      .attr("offset", "100%")
      .attr("stop-color", "var(--color-gray-400)");

    const line = d3
      .line()
      .x((d) => this._d3XScale(d.date))
      .y((d) => this._d3YScale(d.balance))
      .curve(d3.curveMonotoneX);

    this._d3Group
      .append("path")
      .datum(this._normalizedData)
      .attr("fill", "none")
      .attr("stroke", `url(#${this.element.id}-line-gradient)`)
      .attr("stroke-width", 2)
      .attr("stroke-linejoin", "round")
      .attr("stroke-linecap", "round")
      .attr("d", line);

    // Mark points where balance goes negative
    const negativePoints = this._normalizedData.filter((d) => d.balance < 0);
    negativePoints.forEach((d) => {
      this._d3Group
        .append("circle")
        .attr("cx", this._d3XScale(d.date))
        .attr("cy", this._d3YScale(d.balance))
        .attr("r", 4)
        .attr("fill", "var(--color-destructive)");
    });
  }

  _drawXAxisLabels() {
    const xAxis = d3
      .axisBottom(this._d3XScale)
      .ticks(5)
      .tickSize(0)
      .tickFormat(d3.timeFormat("%b %d"));

    this._d3Group
      .append("g")
      .attr("transform", `translate(0,${this._d3ContainerHeight})`)
      .call(xAxis)
      .select(".domain")
      .remove();

    this._d3Group
      .selectAll(".tick text")
      .attr("class", "fg-gray")
      .style("font-size", "11px");
  }

  _drawTooltip() {
    this._d3Tooltip = d3
      .select(`#${this.element.id}`)
      .append("div")
      .attr(
        "class",
        "bg-container text-sm font-sans absolute p-3 border border-secondary rounded-lg pointer-events-none opacity-0 shadow-lg"
      );
  }

  _trackMouseForShowingTooltip() {
    const bisectDate = d3.bisector((d) => d.date).left;

    this._d3Group
      .append("rect")
      .attr("width", this._d3ContainerWidth)
      .attr("height", this._d3ContainerHeight)
      .attr("fill", "none")
      .attr("pointer-events", "all")
      .on("mousemove", (event) => {
        const estimatedTooltipWidth = 200;
        const pageWidth = document.body.clientWidth;
        const tooltipX = event.pageX + 10;
        const overflowX = tooltipX + estimatedTooltipWidth - pageWidth;
        const adjustedX =
          overflowX > 0 ? event.pageX - overflowX - 20 : tooltipX;

        const [xPos] = d3.pointer(event);
        const x0 = bisectDate(
          this._normalizedData,
          this._d3XScale.invert(xPos),
          1
        );
        const d0 = this._normalizedData[x0 - 1];
        const d1 = this._normalizedData[x0];

        if (!d0 || !d1) return;

        const d =
          xPos - this._d3XScale(d0.date) > this._d3XScale(d1.date) - xPos
            ? d1
            : d0;

        // Reset
        this._d3Group.selectAll(".data-point-circle").remove();
        this._d3Group.selectAll(".guideline").remove();

        // Guideline
        this._d3Group
          .append("line")
          .attr("class", "guideline fg-subdued")
          .attr("x1", this._d3XScale(d.date))
          .attr("y1", 0)
          .attr("x2", this._d3XScale(d.date))
          .attr("y2", this._d3ContainerHeight)
          .attr("stroke", "currentColor")
          .attr("stroke-dasharray", "4, 4");

        // Circle
        this._d3Group
          .append("circle")
          .attr("class", "data-point-circle")
          .attr("cx", this._d3XScale(d.date))
          .attr("cy", this._d3YScale(d.balance))
          .attr("r", 6)
          .attr("fill", d.balance >= 0 ? "var(--color-info)" : "var(--color-destructive)");

        // Tooltip content
        this._d3Tooltip
          .html(this._tooltipTemplate(d))
          .style("opacity", 1)
          .style("z-index", 999)
          .style("left", `${adjustedX}px`)
          .style("top", `${event.pageY - 10}px`);
      })
      .on("mouseout", () => {
        this._d3Group.selectAll(".guideline").remove();
        this._d3Group.selectAll(".data-point-circle").remove();
        this._d3Tooltip.style("opacity", 0);
      });
  }

  _tooltipTemplate(datum) {
    const formattedDate = d3.timeFormat("%B %d, %Y")(datum.date);
    const formattedBalance = new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
    }).format(datum.balance);
    const confidence = Math.round(datum.confidence * 100);

    return `
      <div class="text-secondary text-xs mb-1">${formattedDate}</div>
      <div class="text-primary font-medium ${
        datum.balance < 0 ? "text-destructive" : ""
      }">${formattedBalance}</div>
      <div class="text-xs text-subdued mt-1">
        Confidence: ${confidence}%
        ${
          datum.projections_count > 0
            ? `• ${datum.projections_count} transaction${datum.projections_count > 1 ? "s" : ""}`
            : ""
        }
      </div>
    `;
  }

  get _normalizedData() {
    return (this.dataValue || []).map((d) => ({
      date: typeof d.date === "string" ? parseLocalDate(d.date) : d.date,
      balance: Number(d.balance),
      confidence: Number(d.confidence || 1),
      net_change: Number(d.net_change || 0),
      projections_count: Number(d.projections_count || 0),
    }));
  }

  _createMainSvg() {
    return this._d3Container
      .append("svg")
      .attr("width", this._d3InitialContainerWidth)
      .attr("height", this._d3InitialContainerHeight)
      .attr("viewBox", [
        0,
        0,
        this._d3InitialContainerWidth,
        this._d3InitialContainerHeight,
      ]);
  }

  _createMainGroup() {
    return this._d3Svg
      .append("g")
      .attr(
        "transform",
        `translate(${this._margin.left},${this._margin.top})`
      );
  }

  get _d3Svg() {
    if (!this._d3SvgMemo) {
      this._d3SvgMemo = this._createMainSvg();
    }
    return this._d3SvgMemo;
  }

  get _d3Group() {
    if (!this._d3GroupMemo) {
      this._d3GroupMemo = this._createMainGroup();
    }
    return this._d3GroupMemo;
  }

  get _margin() {
    return { top: 10, right: 10, bottom: 25, left: 10 };
  }

  get _d3ContainerWidth() {
    return (
      this._d3InitialContainerWidth - this._margin.left - this._margin.right
    );
  }

  get _d3ContainerHeight() {
    return (
      this._d3InitialContainerHeight - this._margin.top - this._margin.bottom
    );
  }

  get _d3Container() {
    return d3.select(this.element);
  }

  get _d3XScale() {
    return d3
      .scaleTime()
      .rangeRound([0, this._d3ContainerWidth])
      .domain(d3.extent(this._normalizedData, (d) => d.date));
  }

  get _d3YScale() {
    const dataMin = d3.min(this._normalizedData, (d) => d.balance);
    const dataMax = d3.max(this._normalizedData, (d) => d.balance);

    // Always include zero in the scale if data crosses zero or is all negative
    const yMin = Math.min(0, dataMin);
    const yMax = Math.max(0, dataMax);

    // Add some padding
    const padding = (yMax - yMin) * 0.1;

    return d3
      .scaleLinear()
      .rangeRound([this._d3ContainerHeight, 0])
      .domain([yMin - padding, yMax + padding]);
  }

  _setupResizeObserver() {
    this._resizeObserver = new ResizeObserver(() => {
      this._reinstall();
    });
    this._resizeObserver.observe(this.element);
  }
}
