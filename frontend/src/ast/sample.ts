// src/ast/sample.ts

import { DocumentNode } from "./types"

export const sampleDocument: DocumentNode = {
  id: "doc-1",
  type: "document",

  children: [
    {
      id: "h1",
      type: "heading",
      level: 1,

      children: [
        {
          text: "Research Workspace"
        }
      ]
    },

    {
      id: "p1",
      type: "paragraph",

      children: [
        {
          text: "This document is rendered using "
        },
        {
          text: "Slate",
          bold: true
        },
        {
          text: " but stored using our own AST."
        }
      ]
    }
  ]
}