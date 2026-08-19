import Header from "./components/Header"
import MainPanel from "./components/MainPanel"
import Sidebar from "./components/Sidebar"
import SummaryPanel from "./components/SummaryPanel"
import { useState } from "react"

function App() {
  const [selectedTopic, setSelectedTopic] = useState("growth")
  return (
    <div className="app">
      <Header />

      <div className="workspace">
        <Sidebar
          selectedTopic={selectedTopic}
          setSelectedTopic={setSelectedTopic}
        />
        <MainPanel selectedTopic={selectedTopic}/>
        <SummaryPanel />
      </div>
    </div>
  )
}

export default App