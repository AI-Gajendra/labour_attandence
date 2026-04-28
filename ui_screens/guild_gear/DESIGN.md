# Design System Documentation: The Industrial Atelier

## 1. Overview & Creative North Star
**Creative North Star: The Industrial Atelier**
This design system moves away from the sterile, "template-centric" nature of workforce management tools. Instead, it adopts the aesthetic of a high-end architectural firm—blending the raw utility of labor management with a sophisticated, editorial lens. 

We achieve a premium feel by rejecting standard UI crutches like heavy borders and generic grids. Instead, we use **intentional asymmetry**, **tonal layering**, and **expansive white space**. The interface should feel like a bespoke digital workspace where every element—from a shift card to a payroll graph—is treated with the care of a gallery piece. We lean into the high-contrast "Command Center" feel of the dark navy headers against the warm, organic neutrality of the workspace.

---

## 2. Colors & Surface Philosophy
The palette is rooted in a "Deep Anchor" strategy. The `on_primary_fixed` (#121826) serves as the grounding force for headers and navigation, providing an authoritative, professional atmosphere.

### The "No-Line" Rule
To maintain a high-end editorial aesthetic, **1px solid borders are prohibited for sectioning.** Boundaries must be defined through:
*   **Background Shifts:** Placing a `surface_container_low` card on a `surface` background.
*   **Tonal Transitions:** Using depth to imply containment rather than literal lines.

### Surface Hierarchy & Nesting
Treat the UI as a physical stack of fine paper. 
*   **Base:** `surface` (#FAF9F6) is your canvas.
*   **Sectioning:** Use `surface_container_low` (#F4F3F0) for large background blocks.
*   **Interactive Elements:** Use `surface_container_lowest` (#FFFFFF) for cards to make them "pop" subtly against the warm background.

### The "Glass & Gradient" Rule
Standard flat colors feel "out of the box." To provide "visual soul," apply a subtle linear gradient to main CTAs (e.g., transitioning from `secondary` #10B981 to a slightly darker custom tint). For floating action buttons or overlays, utilize **Glassmorphism**: 
*   **Fill:** `surface_container_lowest` at 80% opacity.
*   **Effect:** 16px–24px Backdrop Blur.

---

## 3. Typography
We utilize a dual-typeface system to bridge the gap between "Industrial" and "Editorial."

*   **Display & Headlines (Manrope):** Chosen for its geometric precision. Use `display-lg` and `headline-md` to create "Hero Moments" in the UI—such as total hours worked or active site names. These should feel authoritative.
*   **Body & Labels (Inter):** The workhorse. Inter provides maximum legibility for dense data (worker names, timestamps, technical specs).

**Editorial Hint:** Use `title-lg` in `on_surface_variant` (#45464C) for secondary information to create a sophisticated, low-contrast hierarchy that guides the eye toward primary data points.

---

## 4. Elevation & Depth
In this system, elevation is a product of light and material, not just math.

*   **Tonal Layering Principle:** Depth is achieved by "stacking" the `surface-container` tiers. A `surface_container_highest` element should only be used for the most transient items (like pop-up menus) to distinguish them from the base layout.
*   **Ambient Shadows:** When a "floating" effect is required, shadows must be extra-diffused. 
    *   *Formula:* `Y: 8px, Blur: 24px, Spread: 0, Color: rgba(21, 27, 41, 0.06)`. This uses a tinted version of our navy header color to mimic natural, ambient light.
*   **The "Ghost Border" Fallback:** If a border is required for accessibility, use the `outline_variant` token at **15% opacity**. A 100% opaque border is a failure of the design's breathability.

---

## 5. Components

### Primary Action Buttons
*   **Height:** 64px (Mandatory for high-intensity labor environments).
*   **Corner Radius:** `xl` (1.5rem) to provide a friendly, modern contrast to sharp data.
*   **Style:** Use a subtle gradient and a 4px inner-glow (top-down) to give the button a tactile, "pressed" feel even in its idle state.

### Information Cards
*   **Constraint:** No divider lines. 
*   **Hierarchy:** Use `title-md` for the header and `body-sm` for metadata. 
*   **Separation:** Content groups within a card should be separated by 16px–24px of vertical white space or a subtle `surface_variant` background tint.

### The "Shift-Status" Chips
*   **Styling:** Use the vibrant accent tokens (`secondary` for active, `tertiary_container` for scheduled, `error` for alert).
*   **Design:** Use a "Pill" shape (`full` roundedness) with a 10% opacity background of the accent color and 100% opacity text for a refined, modern look.

### Input Fields
*   **Height:** 64px.
*   **State:** When focused, use a 2px "Ghost Border" (20% opacity of `secondary` green) to indicate activity without cluttering the screen.

### Specialized Component: The "At-A-Glance" Header
*   **Background:** `primary_container` (#121826).
*   **Layout:** Use asymmetrical padding (32px top, 16px bottom) to create an editorial feel. Overlap the first card of the page content 24px into the header area to create a sense of unified layering.

---

## 6. Do's and Don'ts

### Do
*   **Do** use asymmetrical spacing. A 24px left margin and 16px right margin can make a dashboard feel like a premium magazine layout.
*   **Do** leverage the `64px` tap target for all interactive elements to ensure accessibility for users in high-activity environments.
*   **Do** use `surface_dim` for "disabled" states rather than just lowering opacity; this maintains the "material" feel of the system.

### Don't
*   **Don't** use pure black (#000000) for text. Always use `on_surface` or `on_surface_variant` to keep the palette warm and professional.
*   **Don't** use standard "drop shadows." If the element doesn't feel like it's naturally lifting off the `FAF9F6` surface, refine the blur and opacity.
*   **Don't** use icons as the sole indicator of an action. Pair them with `label-md` text to ensure professional clarity.

---