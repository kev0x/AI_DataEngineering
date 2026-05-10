/**
 * Purpose: Boots the React dashboard into the browser DOM.
 * Runtime role: Connects the App component to the #root element from Frontend/index.html and loads global styling.
 * Dependencies: React, ReactDOM, Frontend/src/App.jsx, and Frontend/src/styles.css.
 */

import React from "react";
import { createRoot } from "react-dom/client";
import App from "./App.jsx";
import "./styles.css";

createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
