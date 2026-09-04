import { Descendant, Element as SlateElement, Text } from "slate"

import {
  DocumentNode,
  BlockNode,
  ParagraphNode,
  HeadingNode,
  TextNode,
} from "./types"

export function fromSlate(nodes: Descendant[]): DocumentNode {
  return {
    id: crypto.randomUUID(),
    type: "document",
    children: nodes.map(fromSlateBlock),
  }
}

function fromSlateBlock(node: Descendant): BlockNode {
  if (!SlateElement.isElement(node))
    throw new Error("Expected Slate Element")

  switch (node.type) {
    case "paragraph":
      return {
        id: crypto.randomUUID(),
        type: "paragraph",
        children: node.children.map(fromSlateText),
      }

    case "heading":
      return {
        id: crypto.randomUUID(),
        type: "heading",
        level: node.level ?? 1,
        children: node.children.map(fromSlateText),
      }

    default:
      throw new Error(`Unsupported node type: ${node}`)
  }
}

function fromSlateText(node: Descendant): TextNode {
  if (!Text.isText(node))
    throw new Error("Expected Slate Text")

  return {
    text: node.text,

    bold: node.bold,
    italic: node.italic,
    underline: node.underline,
  }
}