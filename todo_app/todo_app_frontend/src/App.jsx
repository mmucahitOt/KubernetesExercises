import { config } from './config/env'

function App() {
  console.log("config.apiUrl: ", config.apiUrl)
  return (
    <div className="app">
      <h1>The project App</h1>
      <img src={config.apiUrl + "/randomimage"} alt="Random" />
      <h4>DevOps with Kubernetes 2025</h4>
    </div>
  )
}

export default App