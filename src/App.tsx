import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { UserProvider } from '@/contexts/UserContext';
import { ClassProvider } from '@/contexts/ClassContext';
import { PreferencesProvider } from '@/contexts/PreferencesContext';
import { Layout } from '@/components/Layout';
import { Dashboard } from '@/pages/Dashboard';
import { Schedule } from '@/pages/Schedule';
import { MyClasses } from '@/pages/MyClasses';
import { Settings } from '@/pages/Settings';
import { Profile } from '@/pages/Profile';
import { useUserState } from '@/hooks/useUserState';
import { LoginForm } from '@/pages/Login';

// Loading component
const LoadingScreen: React.FC = () => (
  <div className="flex min-h-screen flex-col items-center justify-center bg-background text-foreground">
    <div className="space-y-4 text-center">
      <h1 className="text-4xl font-bold">Dance Class Management App</h1>
      <p className="text-muted-foreground">Loading...</p>
    </div>
  </div>
);

// App routes component
const AppRoutes: React.FC = () => {
  const { loading: userLoading } = useUserState();

  if (userLoading) {
    return <LoadingScreen />;
  }

  return (
    <Layout>
      <Routes>
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/schedule" element={<Schedule />} />
        <Route path="/my-classes" element={<MyClasses />} />
        <Route path="/profile" element={<Profile />} />
        <Route path="/settings" element={<Settings />} />
        <Route path="/login" element={<LoginForm />} />
        {/* Catch all route - redirect to dashboard */}
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </Layout>
  );
};

// Main App component with providers
function App() {
  return (
    <Router>
      <UserProvider>
        <PreferencesProvider>
          <ClassProvider>
            <AppRoutes />
          </ClassProvider>
        </PreferencesProvider>
      </UserProvider>
    </Router>
  );
}

export default App
