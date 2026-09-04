import { useMemo, useState } from "react"
import { createEditor, Descendant } from "slate"
import { Slate, Editable, withReact } from "slate-react"

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

  return (
    <Slate
      editor={editor}
      initialValue={value}
      onChange={setValue}
    >
      <Editable
        renderElement={(props) => <Element {...props} />}
        renderLeaf={(props) => <Leaf {...props} />}
        placeholder="Start typing..."
      />
    </Slate>
  )
}