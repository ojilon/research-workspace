import type { FileTreeNode } from "../types";

/**
 * Placeholder local tree until the Python backend + local disk root are wired.
 * Demonstrates folders, documents, and bookmark links (e.g. ResearchGate papers).
 */
export const sampleTree: FileTreeNode[] = [
  {
    id: "folder-cell-bio",
    name: "Cell Biology",
    kind: "folder",
    children: [
      {
        id: "doc-notes-1",
        name: "Session notes.md",
        kind: "document",
        path: "Cell Biology/Session notes.md",
      },
      {
        id: "link-rg-1",
        name: "ResearchGate – Mitosis review",
        kind: "link",
        url: "https://www.researchgate.net/",
      },
      {
        id: "link-rg-2",
        name: "Paper: Cell cycle checkpoints",
        kind: "link",
        url: "https://www.researchgate.net/",
      },
    ],
  },
  {
    id: "folder-plant-phys",
    name: "Plant Physiology",
    kind: "folder",
    children: [
      {
        id: "doc-growth",
        name: "Growth summary.md",
        kind: "document",
        path: "Plant Physiology/Growth summary.md",
      },
      {
        id: "doc-photosynthesis",
        name: "Photosynthesis notes.md",
        kind: "document",
        path: "Plant Physiology/Photosynthesis notes.md",
      },
    ],
  },
  {
    id: "folder-bookmarks",
    name: "Quick Bookmarks",
    kind: "folder",
    children: [
      {
        id: "link-pubmed",
        name: "PubMed",
        kind: "link",
        url: "https://pubmed.ncbi.nlm.nih.gov/",
      },
    ],
  },
];
