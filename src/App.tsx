import { Routes, Route } from 'react-router-dom';
import LoginPage from './pages/LoginPage';
import SignUpPage from './pages/SignUpPage';
import HomePage from './pages/HomePage';
import ForumPage from './pages/ForumPage';
import ProfilePage from './pages/ProfilePage';
import SettingsPage from './pages/SettingsPage'; // Added
import ProtectedRoute from './components/auth/ProtectedRoute';
import AdminRoute from './components/auth/AdminRoute';
import MainLayout from './components/layout/MainLayout';
import AdminLayout from './components/layout/AdminLayout';
import AdminDashboardPage from './pages/admin/AdminDashboardPage';
import UserManagementPage from './pages/admin/UserManagementPage';
import ModerationPage from './pages/admin/ModerationPage';
import SectionManagementPage from './pages/admin/SectionManagementPage';
import { Toaster } from "@/components/ui/toaster";

function App() {
  return (
    <>
      <Routes>
        {/* Public routes */}
        <Route path="/connexion" element={<LoginPage />} />
        <Route path="/inscription" element={<SignUpPage />} />

        {/* Protected routes for regular users */}
        <Route element={<ProtectedRoute />}>
          <Route element={<MainLayout />}>
            <Route path="/" element={<HomePage />} />
            <Route path="/forum" element={<ForumPage />} />
            <Route path="/profil/:userId" element={<ProfilePage />} />
            <Route path="/parametre" element={<SettingsPage />} /> {/* Added settings route */}
            {/* <Route path="/forum/categorie/:categorySlug" element={<CategoryPostsPage />} /> */}
            {/* <Route path="/forum/sujet/:postId" element={<PostDetailPage />} /> */}
          </Route>
        </Route>

        {/* Protected routes for admin/moderator users */}
        {/* First, ProtectedRoute ensures user is authenticated and profile (with status) is loaded */}
        <Route element={<ProtectedRoute />}> 
          {/* Then, AdminRoute checks for profile.status === 'approved' and profile.role is MODERATOR, ADMIN, or SUPER_ADMIN */}
          <Route path="/admin" element={<AdminRoute />}> 
            <Route element={<AdminLayout />}>
              <Route index element={<AdminDashboardPage />} />
              <Route path="users" element={<UserManagementPage />} /> {/* Access control within component or specific route for ADMIN+ */}
              <Route path="moderation" element={<ModerationPage />} /> {/* MODERATOR+ */}
              <Route path="sections" element={<SectionManagementPage />} /> {/* Access control within component or specific route for ADMIN+ */}
            </Route>
          </Route>
        </Route>
        
        {/* <Route path="*" element={<NotFoundPage />} /> */}
      </Routes>
      <Toaster />
    </>
  );
}

export default App;
