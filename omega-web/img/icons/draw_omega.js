globalThis.drawOmega = function (ctx, outerCircleColor, innerCircleColor) {
  ctx.globalCompositeOperation = "source-over";
  ctx.strokeStyle = outerCircleColor;

  ctx.beginPath();
  ctx.lineWidth = 0.25;
  ctx.arc(0.5, 0.5, 0.375, 0, Math.PI * 2, true);

  ctx.closePath();
  ctx.stroke();

  if (innerCircleColor != null) {
    ctx.fillStyle = innerCircleColor;
  } else {
    ctx.globalCompositeOperation = "destination-out";
  }

  ctx.beginPath();
  ctx.arc(0.5, 0.5, 0.25, 0, Math.PI * 2, true);
  ctx.closePath();
  ctx.fill();
};

globalThis.drawOmegaActivity = function (
  ctx, outerCircleColor, innerCircleColor, activityColor, showDot
) {
  globalThis.drawOmega(ctx, activityColor || outerCircleColor, innerCircleColor);
  if (showDot) {
    ctx.globalCompositeOperation = "source-over";
    ctx.fillStyle = "#ffffff";
    ctx.beginPath();
    ctx.arc(0.79, 0.21, 0.21, 0, Math.PI * 2, true);
    ctx.closePath();
    ctx.fill();

    ctx.fillStyle = "#ff3b30";
    ctx.beginPath();
    ctx.arc(0.79, 0.21, 0.145, 0, Math.PI * 2, true);
    ctx.closePath();
    ctx.fill();
  }
};
