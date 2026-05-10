/**
 * Purpose: Renders a consistent empty-state message inside dashboard panels.
 * Runtime role: Keeps chart and table components visually stable when filters remove all rows.
 * Dependencies: CSS empty-state classes and parent-provided message text.
 */

export function EmptyPanelMessage({ message }) {
  return <div className="emptyPanelMessage">{message}</div>;
}
