import { useCallback, useEffect, useRef, useState } from "react";

type UseResizableOptions = {
  /** Starting width in pixels. */
  initialWidth: number;
  /** Minimum width the panel is allowed to shrink to. */
  minWidth?: number;
  /** Maximum width the panel is allowed to grow to. */
  maxWidth?: number;
  /** Which side the drag handle sits on (affects mouse delta). */
  side?: "left" | "right";
};

/**
 * Lightweight resizable panel width.
 * Attach `onMouseDown` from the returned handle to a vertical drag strip.
 */
export function useResizable({
  initialWidth,
  minWidth = 180,
  maxWidth = 480,
  side = "left",
}: UseResizableOptions) {
  const [width, setWidth] = useState(initialWidth);
  const dragging = useRef(false);
  const startX = useRef(0);
  const startWidth = useRef(initialWidth);

  const onMouseDown = useCallback(
    (e: React.MouseEvent) => {
      e.preventDefault();
      dragging.current = true;
      startX.current = e.clientX;
      startWidth.current = width;
      document.body.style.cursor = "col-resize";
      document.body.style.userSelect = "none";
    },
    [width]
  );

  useEffect(() => {
    function onMouseMove(e: MouseEvent) {
      if (!dragging.current) return;
      const delta =
        side === "left"
          ? e.clientX - startX.current
          : startX.current - e.clientX;
      const next = Math.min(
        maxWidth,
        Math.max(minWidth, startWidth.current + delta)
      );
      setWidth(next);
    }

    function onMouseUp() {
      if (!dragging.current) return;
      dragging.current = false;
      document.body.style.cursor = "";
      document.body.style.userSelect = "";
    }

    window.addEventListener("mousemove", onMouseMove);
    window.addEventListener("mouseup", onMouseUp);
    return () => {
      window.removeEventListener("mousemove", onMouseMove);
      window.removeEventListener("mouseup", onMouseUp);
    };
  }, [minWidth, maxWidth, side]);

  return { width, setWidth, onMouseDown };
}
