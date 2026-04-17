import React, { useEffect, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';

const Navbar = () => {
    const { pathname } = useLocation();
    const [scrolled, setScrolled] = useState(false);

    useEffect(() => {
        const handleScroll = () => {
            setScrolled(window.scrollY > 20);
        };
        window.addEventListener('scroll', handleScroll, { passive: true });
        return () => window.removeEventListener('scroll', handleScroll);
    }, []);

    const navItems = [
        { to: '/', label: 'Home' },
        { to: '/about', label: 'About' },
        { to: '/help', label: 'Help & Support' },
    ];

    return (
        <nav className={`navbar ${scrolled ? 'navbar--scrolled' : ''}`}>
            <div className="navbar-inner">
                <Link to="/" className="navbar-logo flex items-center gap-1.5 group">
                    <span className="text-white">WhereIs</span>
                    <span className="text-[var(--gold)]">My</span>
                    <span className="text-white">Bus</span>
                </Link>
                <div className="navbar-links">
                    {navItems.map(item => (
                        <Link
                            key={item.to}
                            to={item.to}
                            className={`navbar-link ${pathname === item.to ? 'active' : ''}`}
                        >
                            <span className="text-[10px] font-black uppercase tracking-[0.2em]">{item.label}</span>
                        </Link>
                    ))}
                    <div className="navbar-divider !h-4" />
                    <Link to="/login" className="navbar-btn !text-[10px] !font-black !uppercase !tracking-[0.2em] navbar-btn--ghost">Access</Link>
                    <Link to="/register" className="navbar-btn !text-[10px] !font-black !uppercase !tracking-[0.2em] navbar-btn--solid">Register</Link>
                </div>
            </div>
        </nav>
    );
};

export default Navbar;
