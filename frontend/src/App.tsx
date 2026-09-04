import { DocumentEditor } from "./editor/DocumentEditor"
import { sampleDocument } from "./ast/sample"

function App() {
  return (
    <DocumentEditor
      document={sampleDocument}
    />
  )
}

export default App