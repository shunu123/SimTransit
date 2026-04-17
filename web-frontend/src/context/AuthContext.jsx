import React, { createContext, useState, useContext, useEffect } from 'react';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
    const [user, setUser] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        // Here you would typically check for a saved session/token in localStorage
        const savedUser = localStorage.getItem('user');
        if (savedUser) {
            try {
                const rawUser = JSON.parse(savedUser);
                // Normalize role in case it was stored before normalization was added
                if (!rawUser.role && (rawUser.is_admin || rawUser.user_type)) {
                    rawUser.role = rawUser.is_admin === true || rawUser.user_type === 'admin' ? 'admin' : 'user';
                    localStorage.setItem('user', JSON.stringify(rawUser));
                }
                setUser(rawUser);
            } catch (e) {
                console.error("Failed to parse saved user");
            }
        }
        setLoading(false);
    }, []);

    const login = (userData) => {
        // Handle nested user object if present (e.g., from backend logic response)
        const rawUser = userData.user || userData;
        // Normalize role — backend may use 'role', 'is_admin', or 'user_type'
        const normalizedRole = rawUser.role ||
            (rawUser.is_admin === true ? 'admin' : null) ||
            (rawUser.user_type === 'admin' ? 'admin' : null) ||
            'user';
        const userToStore = { ...rawUser, role: normalizedRole };
        console.info('[Auth] Logged in user:', userToStore.name, '| Role:', userToStore.role);
        setUser(userToStore);
        localStorage.setItem('user', JSON.stringify(userToStore));
    };

    const logout = () => {
        setUser(null);
        localStorage.removeItem('user');
    };

    return (
        <AuthContext.Provider value={{ user, login, logout, loading }}>
            {!loading && children}
        </AuthContext.Provider>
    );
};

export const useAuth = () => {
    const context = useContext(AuthContext);
    if (!context) {
        throw new Error('useAuth must be used within an AuthProvider');
    }
    return context;
};
