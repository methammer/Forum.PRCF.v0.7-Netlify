import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.tsx'
import './index.css'
import { BrowserRouter } from 'react-router-dom'
import { UserProvider } from './contexts/UserContext.tsx'; // Import UserProvider

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <BrowserRouter>
      <UserProvider> {/* Wrap App with UserProvider */}
        <App />
      </UserProvider>
    </BrowserRouter>
  </React.StrictMode>,
)
