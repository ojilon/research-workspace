import type { Topic } from "../types";

/**
 * Sample plant-physiology topics.
 * Used only until local file storage is wired up.
 * description is a plain string; section content is an array of ContentBlocks.
 */
export const topics: Topic[] = [
  {
    id: "growth",
    name: "Growth",
    description:
      "Plants grow throughout their life because of meristematic tissues.",
    sections: [
      {
        id: "introduction",
        title: "Introduction",
        content: [
          { type: "paragraph", text: "Introduction content goes here." },
        ],
      },
      {
        id: "growth-regulators",
        title: "Growth Regulators",
        content: [
          { type: "paragraph", text: "Growth regulators content goes here." },
        ],
      },
      {
        id: "growth-measurement",
        title: "Growth Measurement",
        content: [
          { type: "paragraph", text: "Growth measurement content goes here." },
        ],
      },
    ],
  },
  {
    id: "water-relations",
    name: "Water Relations",
    description: "Study of water movement and balance in plants.",
    sections: [
      {
        id: "water-potential",
        title: "Water potential",
        content: [
          { type: "paragraph", text: "Water potential content goes here." },
        ],
      },
      {
        id: "osmosis",
        title: "Osmosis",
        content: [{ type: "paragraph", text: "Osmosis content goes here." }],
      },
      {
        id: "transpiration",
        title: "Transpiration",
        content: [
          { type: "paragraph", text: "Transpiration content goes here." },
        ],
      },
    ],
  },
  {
    id: "photosynthesis",
    name: "Photosynthesis",
    description:
      "Study of how plants convert light energy into chemical energy.",
    sections: [
      {
        id: "light-reactions",
        title: "Light reactions",
        content: [
          { type: "paragraph", text: "Content for light reactions here." },
        ],
      },
      {
        id: "calvin-cycle",
        title: "Calvin Cycle",
        content: [
          {
            type: "paragraph",
            text: "Content for Calvin Cycle reactions here.",
          },
        ],
      },
      {
        id: "factors-affecting-photosynthesis",
        title: "Factors affecting photosynthesis",
        content: [
          {
            type: "paragraph",
            text: "Content for factors-affecting-photosynthesis here.",
          },
        ],
      },
    ],
  },
];
