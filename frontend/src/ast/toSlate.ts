// src/ast/toSlate.ts

import { Descendant } from "slate"
import {
  DocumentNode,
  BlockNode,
  ParagraphNode,
  HeadingNode,
  TextNode,
} from "./types"

export function toSlate(document: DocumentNode): Descendant[] {
  return document.children.map(toSlateBlock)
}

function toSlateBlock(block: BlockNode): Descendant {
  switch (block.type) {
    case "paragraph":
      return paragraphToSlate(block)

    case "heading":
      return headingToSlate(block)

    default:
      throw new Error(`Unsupported block type`)
  }
}

function paragraphToSlate(node: ParagraphNode): Descendant {
  return {
    type: "paragraph",
    children: node.children.map(toSlateText),
  }
}

function headingToSlate(node: HeadingNode): Descendant {
  return {
    type: "heading",
    level: node.level,
    children: node.children.map(toSlateText),
  }
}

function toSlateText(node: TextNode) {
  return {
    text: node.text,

    bold: node.bold,
    italic: node.italic,
    underline: node.underline,
  }
}