function Tooltip(link, options) {
  options = options || {};
  options.tooltipOffset = options.tooltipOffset || {x: 0, y: 0};
  options.shift = options.shift || 0;
  options.screenPadding = options.screenPadding || 16;
  options.initialDirection = options.initialDirection || TooltipDirection.DOWN;
  var self = this;

  self.tooltip = document.createElement("div");
  self.tooltip.className = "crossdart-tooltip";
  self.arrowContainer = document.createElement("div");
  self.arrowContainer.className = "crossdart-tooltip--arrow-container";
  self.arrow = document.createElement("div");
  self.arrow.className = "crossdart-tooltip--arrow";
  self.container = document.createElement("div");
  self.container.className = "crossdart-tooltip--container";
  self.tooltip.appendChild(self.arrowContainer);
  self.arrowContainer.appendChild(self.arrow);
  self.tooltip.appendChild(self.container);

  this.show = function () {
    if (!isAttached()) {
      attach();
    }
    setTimeout(function () {
      self.tooltip.classList.add("is-visible");
      reposition(options.initialDirection, options.tooltipOffset);
      var listener = function () {
        self.tooltip.removeEventListener("transitionend", listener);
      };
      self.tooltip.addEventListener("transitionend", listener);
    }, 0);
  };

  this.hide = function () {
    if (isAttached()) {
      setTimeout(function () {
        self.tooltip.classList.remove("is-visible");
      });
    }
  };

  this.isVisible = function () {
    return self.tooltip.classList.contains("is-visible");
  };

  this.destroy = function () {
    if (isAttached()) {
      self.tooltip.parentNode.removeChild(self.tooltip);
    }
  };

  this.setContent = function (content) {
    while (self.container.firstChild) {
      self.container.removeChild(self.container.firstChild);
    }
    self.container.appendChild(content);
  };

  function windowBounds() {
    return {
      top: window.pageXOffset,
      left: window.pageYOffset,
      right: window.pageXOffset + window.innerWidth,
      bottom: window.pageYOffset + window.innerHeight
    };
  }

  function tooltipBounds() {
    var rect = self.tooltip.getBoundingClientRect();
    return {
      left: rect.left,
      right: rect.right,
      top: rect.top + window.scrollY,
      bottom: rect.bottom + window.scrollY
    }
  }

  function doesExceedTopEdge(direction) {
    return tooltipBounds().top < (direction.isVertical() ? 0 : options.screenPadding);
  }

  function doesExceedBottomEdge(direction) {
    var edge = windowBounds().bottom;
    if (direction.isHorizontal()) {
      edge -= options.screenPadding;
    }
    return tooltipBounds().bottom > edge;
  }

  function doesExceedLeftEdge(direction) {
    return tooltipBounds().left < (direction.isHorizontal() ? 0 : options.screenPadding);
  }

  function doesExceedRightEdge(direction) {
    var edge = windowBounds().right;
    if (direction.isVertical()) {
      edge -= options.screenPadding;
    }
    return tooltipBounds().right > edge;
  }

  function isVisibleOnScreenInSameDirection(direction) {
    if (direction.isVertical()) {
      return !doesExceedTopEdge(direction) && !doesExceedBottomEdge(direction);
    } else {
      return !doesExceedLeftEdge(direction) && !doesExceedRightEdge(direction);
    }
  }

  function isVisibleOnScreenInPerpendicularDirection(direction) {
    if (direction.isHorizontal()) {
      return !doesExceedTopEdge(direction) && !doesExceedBottomEdge(direction);
    } else {
      return !doesExceedLeftEdge(direction) && !doesExceedRightEdge(direction);
    }
  }

  function isAttached() {
    return self.tooltip.parentNode !== null;
  }

  function attach() {
    document.body.appendChild(self.tooltip);
  }

  function reposition(direction, tooltipOffset, opts) {
    opts = opts || {};
    opts.isAdjustedInSameDirection =
      (opts.isAdjustedInSameDirection === undefined ? false : opts.isAdjustedInSameDirection);
    opts.isAdjustedInPerpendicularDirection =
      (opts.isAdjustedInPerpendicularDirection === undefined ? false : opts.isAdjustedInPerpendicularDirection);
    TooltipDirection.ALL.forEach(function (d) {
      self.tooltip.classList.remove(d.cssClass());
    });
    self.tooltip.classList.add(direction.cssClass());
    var position = calculatePosition(direction, tooltipOffset);
    setPosition(position, direction);

    if (!isVisibleOnScreenInPerpendicularDirection(direction)  && !opts.isAdjustedInPerpendicularDirection) {
      reposition(direction, adjustOffset(direction), {isAdjustedInPerpendicularDirection: true});
    }
    if (!isVisibleOnScreenInSameDirection(direction) && !opts.isAdjustedInSameDirection) {
      reposition(direction.opposite(), tooltipOffset, {isAdjustedInSameDirection: true});
    }
  }

  function setPosition(position, direction) {
    self.tooltip.style.left = position.point.x.toString() + "px";
    self.tooltip.style.top = position.point.y.toString() + "px";
    if (direction.isVertical()) {
      self.arrow.style.marginLeft = position.arrowMargin.toString() + "px";
    } else {
      self.arrow.style.marginTop = position.arrowMargin.toString() + "px";
    }
  }

  function calculatePosition(direction, tooltipOffset) {
    if (direction.isHorizontal()) {
      return calculateHorizontalPosition(direction, tooltipOffset);
    } else {
      return calculateVerticalPosition(direction, tooltipOffset);
    }
  }

  function linkPoint() {
    var boundingRect = link.getBoundingClientRect();
    return {x: boundingRect.left + window.scrollX, y: boundingRect.top + window.scrollY};
  }

  function parentPoint() {
    var boundingRect = self.tooltip.offsetParent.getBoundingClientRect();
    return {x: boundingRect.left + window.scrollX, y: boundingRect.top + window.scrollY};
  }

  function calculateHorizontalPosition(direction, tooltipOffset) {
    var base = linkPoint().x - parentPoint().x;
    var arrowShift = tooltipOffset.x + self.arrowContainer.offsetWidth;
    var top = linkPoint().y -
      parentPoint().y -
      (self.tooltip.offsetHeight / 2) +
      (link.offsetHeight / 2) +
      options.shift;
    var left;
    if (direction === TooltipDirection.RIGHT) {
      left = base + arrowShift + link.offsetWidth;
    } else {
      left = base - arrowShift - self.tooltip.offsetWidth;
    }
    var point = {x: Math.round(left), y: Math.round(top)};
    var arrowMargin = Math.round(-self.arrow.offsetHeight / 2 + tooltipOffset.y);
    return {point: point, arrowMargin: arrowMargin};
  }

  function calculateVerticalPosition(direction, tooltipOffset) {
    var base = linkPoint().y - parentPoint().y;
    var arrowShift = tooltipOffset.y + self.arrowContainer.offsetHeight;
    var left = -self.tooltip.offsetWidth / 2 +
      options.shift +
      linkPoint().x +
      link.offsetWidth / 2 -
      tooltipOffset.x -
      parentPoint().x;
    var top;
    if (direction === TooltipDirection.DOWN) {
      top = base + arrowShift + link.offsetHeight;
    } else {
      top = base - arrowShift - self.tooltip.offsetHeight;
    }
    var point = {x: Math.round(left), y: Math.round(top)};
    var arrowMargin = Math.round(-self.arrow.offsetWidth / 2 + tooltipOffset.x);
    return {point: point, arrowMargin: arrowMargin};
  }

  function adjustOffset(direction) {
    var overflow;
    if (direction.isVertical()) {
      if (doesExceedLeftEdge(direction)) {
        overflow = options.screenPadding - tooltipBounds().left;
        return {x: options.tooltipOffset.x - overflow, y: options.tooltipOffset.y};
      } else if (doesExceedRightEdge(direction)) {
        overflow = tooltipBounds().left + tooltipBounds().width -
          windowBounds().left + windowBounds().width - options.screenPadding;
        return {x: options.tooltipOffset.x + overflow, y: options.tooltipOffset.y};
      } else {
        return options.tooltipOffset;
      }
    } else {
      if (doesExceedTopEdge(direction)) {
        overflow = options.screenPadding - tooltipBounds().top;
        return {x: options.tooltipOffset.x, y: options.tooltipOffset.y - overflow};
      } else if (doesExceedBottomEdge(direction)) {
        overflow = tooltipBounds().top + tooltipBounds().height -
          windowBounds().top + windowBounds().height - options.screenPadding;
        return {x: options.tooltipOffset.x, y: options.tooltipOffset.y + overflow};
      } else {
        return options.tooltipOffset;
      }
    }
  }

}

function TooltipDirection(value) {
  var self = this;
  self.value = value;

  self.opposite = function () {
    if (value === "up") {
      return TooltipDirection.DOWN;
    } else if (value === "down") {
      return TooltipDirection.UP;
    } else if (value === "left") {
      return TooltipDirection.RIGHT;
    } else if (value === "right") {
      return TooltipDirection.LEFT;
    } else {
      throw "No opposite tooltip direction for " + value;
    }
  };

  self.cssClass = function () {
    return "is-" + value;
  };

  self.isHorizontal = function () {
    return self.type() === "horizontal";
  };

  self.isVertical = function () {
    return self.type() === "vertical";
  };

  self.type = function () {
    return value === "left" || value === "right" ? "horizontal" : "vertical";
  };
}

TooltipDirection.LEFT = new TooltipDirection("left");
TooltipDirection.RIGHT = new TooltipDirection("right");
TooltipDirection.UP = new TooltipDirection("up");
TooltipDirection.DOWN = new TooltipDirection("down");
TooltipDirection.ALL = [
  TooltipDirection.LEFT,
  TooltipDirection.RIGHT,
  TooltipDirection.UP,
  TooltipDirection.DOWN
];
