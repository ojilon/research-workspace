import { defineConfig } from "tailwindcss";
import typography from "@tailwindcss/typography";

export default defineConfig({
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  plugins: [
    typography(),
  ],
});