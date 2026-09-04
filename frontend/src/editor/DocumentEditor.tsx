import { useMemo, useState, useCallback } from "react"
import { createEditor, Descendant } from "slate"
import { Slate, Editable, withReact, RenderElementProps, RenderLeafProps } from "slate-react"

import { DocumentNode } from "../ast/types"
import { toSlate } from "../ast/toSlate"

import { Element } from "./Element"
import { Leaf } from "./Leaf"

interface Props {
  document: DocumentNode
}

export function DocumentEditor({ document }: Props) {
  const editor = useMemo(() => withReact(createEditor()), [])

  const [value, setValue] = useState<Descendant[]>(
    toSlate(document)
  )
  
  const renderElement = useCallback(
      (props: RenderElementProps) => <Element {...props} />,
      []
  )

  const renderLeaf = useCallback(
      (props: RenderLeafProps) => <Leaf {...props} />,
      []
  )

  return (
    <Slate
      editor={editor}
      initialValue={value}
      onChange={setValue}
    >
      <Editable
        renderElement={renderElement}
        renderLeaf={renderLeaf}
        placeholder="Start typing..."
      />
    </Slate>
  )
}