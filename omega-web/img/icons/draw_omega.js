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
