# Editing & composition recipes

Copy-paste starting points. Each = goal + model + input shape + prompt template. Default to
`google/nano-banana-2` for edits and composition; swap in `nano-banana-pro` when fidelity matters.
Pass local files as bytes (`await readFile(path)`), never as a bare path string. See `models.md` for
the full input schema and allowed `aspect_ratio` / `output_resolution` values.

```javascript
import Replicate from "replicate";
import { readFile, writeFile } from "node:fs/promises";
const replicate = new Replicate();

async function save(output, path) {
  const blob = await output[0].blob();
  await writeFile(path, Buffer.from(await blob.arrayBuffer()));
}
```

---

## 1. Object / person removal

Model: `google/nano-banana-2`. Input: one source image + edit prompt; keep the rest intact.

```javascript
const src = await readFile("./scene.jpg");
const out = await replicate.run("google/nano-banana-2", {
  input: {
    prompt: "Remove the person standing on the left. Keep everything else identical, "
          + "including the lighting and the shadows on the ground.",
    image_input: [src],
    aspect_ratio: "match_input_image",
  },
});
await save(out, "scene-clean.jpg");
```

Idiom: name what to remove **and** "keep everything else identical" so the model edits rather than
re-renders the whole frame.

---

## 2. Background swap

Model: `google/nano-banana-2`. Input: subject image + description of the new background.

```text
prompt: "Replace the background with a softly blurred sunlit beach at golden hour.
         Keep the subject, their pose, and the rim lighting on their hair unchanged."
image_input: [subject]
```

---

## 3. Style transfer

Model: `google/nano-banana-2` (or `flux-1.1-pro` for painterly looks). Input: content image + a
described target style (or a style reference image).

```text
prompt: "Re-render this photo in the style of a 1960s screen-printed travel poster:
         flat color blocks, limited palette, bold outlines. Preserve the composition."
image_input: [content]
```

For a reference-driven style, pass both images and say which is content and which is style.

---

## 4. Two-image composition

Model: `google/nano-banana-2`. Input: two (up to 14) references in `image_input`; describe how they
combine.

```javascript
const product = await readFile("./bottle.png");
const scene   = await readFile("./kitchen.jpg");
const out = await replicate.run("google/nano-banana-2", {
  input: {
    prompt: "Place the bottle from image 1 on the kitchen counter from image 2, "
          + "matching the scene's warm lighting and adding a soft contact shadow.",
    image_input: [product, scene],
    aspect_ratio: "4:5",
    output_resolution: "2K",
  },
});
await save(out, "composite.jpg");
```

---

## 5. Product shot with rendered text

Model: `google/nano-banana-2` or `openai/gpt-image-1` (both render readable text). Quote the literal string,
name the font.

```javascript
const photo = await readFile("./product.jpg");
const logo  = await readFile("./logo.png");
const out = await replicate.run("google/nano-banana-2", {
  input: {
    prompt: "Compose a 4:5 advertisement: the product from image 1 centered on a clean "
          + "gradient background, the logo from image 2 in the top-left corner, and a "
          + "headline reading \"Summer Sale\" in bold sans-serif across the bottom.",
    image_input: [photo, logo],
    aspect_ratio: "4:5",
    output_format: "png",
  },
});
await save(out, "ad.png");
```

Idiom: literal text in quotes fixes the characters; the named font fixes the rendering style.

---

## 6. Character consistency across images

Model: `google/nano-banana-2` (or `bytedance/seedream-4` for batches). Input: one or more reference
images of the character; restate the identity each call.

```text
prompt: "Using the character in the reference image, generate the same person now sitting
         at a cafe table reading a book. Keep the face, hairstyle, and outfit identical."
image_input: [character]
```

For a coherent set, prefer SeeDream's batch/sequential generation and ask for N poses with the same
lighting in one call.
