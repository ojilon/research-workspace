import Header from "./components/Header"
import MainPanel from "./components/MainPanel"
import Sidebar from "./components/Sidebar"
import SummaryPanel from "./components/SummaryPanel"

function App() {
  return (
    <div className="app">
      <Header />

      <div className="workspace">
      <Sidebar />
      <MainPanel />
      <SummaryPanel />
      </div>
    </div>
  )
}

export default App