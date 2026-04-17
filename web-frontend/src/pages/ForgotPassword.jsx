import React, { useState, useRef } from 'react';
import MapBackground from '../components/MapBackground';
import { Link, useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { sendOtp, verifyOtp, resetPassword } from '../services/api';
import HackerLoader from '../components/HackerLoader';
import { ShieldAlert, KeyRound, CheckCircle2 } from 'lucide-react';

const ForgotPassword = () => {
    const [step, setStep] = useState('email'); // 'email' | 'otp' | 'new_password' | 'success'
    const [email, setEmail] = useState('');
    const [otp, setOtp] = useState(['', '', '', '']);
    const [newPassword, setNewPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [error, setError] = useState('');
    const [isLoading, setIsLoading] = useState(false);
    const otpRefs = [useRef(), useRef(), useRef(), useRef()];
    const navigate = useNavigate();

    const handleSendOtp = async (e) => {
        e.preventDefault();
        setError('');
        setIsLoading(true);

        try {
            // isRegistration=false means this is for existing users resetting password
            await sendOtp(email, false);
            setStep('otp');
        } catch (err) {
            setError(typeof err === 'string' ? err : 'Failed to send OTP.');
        } finally {
            setIsLoading(false);
        }
    };

    const handleOtpChange = (idx, val) => {
        if (!/^\d?$/.test(val)) return;
        const next = [...otp];
        next[idx] = val;
        setOtp(next);
        if (val && idx < 3) otpRefs[idx + 1].current?.focus();
        if (!val && idx > 0) otpRefs[idx - 1].current?.focus();
    };

    const handleOtpPaste = (e) => {
        const pasted = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 4);
        if (pasted.length === 4) {
            setOtp(pasted.split(''));
            otpRefs[3].current?.focus();
        }
    };

    const handleVerifyOtp = async (e) => {
        e.preventDefault();
        setError('');
        const code = otp.join('');
        if (code.length < 4) { setError('Enter the 4-digit OTP.'); return; }
        setIsLoading(true);

        try {
            // we are verifying OTP using the email
            await verifyOtp(email, code, false, false); 
            setStep('new_password');
        } catch (err) {
            setError(typeof err === 'string' ? err : 'Invalid or expired OTP.');
        } finally {
            setIsLoading(false);
        }
    };

    const handleResetPassword = async (e) => {
        e.preventDefault();
        setError('');
        
        if (newPassword !== confirmPassword) {
            setError('Passwords do not match.');
            return;
        }
        
        if (newPassword.length < 6) {
            setError('Password must be at least 6 characters long.');
            return;
        }

        setIsLoading(true);

        try {
            await resetPassword(email, newPassword);
            setStep('success');
            setTimeout(() => {
                navigate('/login');
            }, 3000);
        } catch (err) {
            setError(typeof err === 'string' ? err : 'Failed to reset password.');
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <div className="map-page">
            <MapBackground />
            <div className="map-overlay" />
            <div className="map-content">
                <AnimatePresence mode="wait">
                    {step === 'email' && (
                        <motion.div
                            key="email"
                            className="glass-card"
                            style={s.card}
                            initial={{ opacity: 0, y: 15, scale: 0.98 }}
                            animate={{ opacity: 1, y: 0, scale: 1 }}
                            exit={{ opacity: 0, y: -10, scale: 0.98 }}
                            transition={{ duration: 0.45 }}
                        >
                            <div style={s.header}>
                                <div style={s.iconWrap}><KeyRound size={32} color="#f59e0b" /></div>
                                <h2 style={s.title}>Forgot Password?</h2>
                                <p style={s.sub}>Enter your admin email to receive a reset code</p>
                            </div>
                            {error && <div style={s.errorBadge}>{error}</div>}
                            <form style={s.form} onSubmit={handleSendOtp}>
                                <div style={s.group}>
                                    <label className="form-label">Email Address</label>
                                    <input
                                        type="email"
                                        className="form-input"
                                        placeholder="admin@saveetha.ac.in"
                                        value={email}
                                        onChange={(e) => setEmail(e.target.value)}
                                        required
                                    />
                                </div>
                                <button className="btn-primary btn-primary--accent" type="submit" disabled={isLoading}>
                                    {isLoading ? 'Sending...' : 'Send OTP'}
                                </button>
                            </form>
                            <div style={s.footer}>
                                Remembered your password? <Link to="/login" style={{ color: '#818cf8', fontWeight: 600 }}>Log In</Link>
                            </div>
                        </motion.div>
                    )}

                    {step === 'otp' && (
                        <motion.div
                            key="otp"
                            className="glass-card"
                            style={s.card}
                            initial={{ opacity: 0, y: 15, scale: 0.98 }}
                            animate={{ opacity: 1, y: 0, scale: 1 }}
                            exit={{ opacity: 0, y: -10, scale: 0.98 }}
                            transition={{ duration: 0.45 }}
                        >
                            <div style={s.header}>
                                <div style={s.iconWrap}><ShieldAlert size={32} color="#f59e0b" /></div>
                                <h2 style={s.title}>Verify OTP</h2>
                                <p style={s.sub}>OTP sent to <strong style={{ color: 'rgba(255,255,255,0.8)' }}>{email}</strong></p>
                            </div>
                            {error && <div style={s.errorBadge}>{error}</div>}
                            <form style={s.form} onSubmit={handleVerifyOtp}>
                                <div style={{ display: 'flex', gap: '12px', justifyContent: 'center' }}>
                                    {otp.map((digit, idx) => (
                                        <input
                                            key={idx}
                                            ref={otpRefs[idx]}
                                            type="text"
                                            inputMode="numeric"
                                            maxLength={1}
                                            value={digit}
                                            onChange={(e) => handleOtpChange(idx, e.target.value)}
                                            onPaste={idx === 0 ? handleOtpPaste : undefined}
                                            style={s.otpBox}
                                            autoFocus={idx === 0}
                                        />
                                    ))}
                                </div>
                                <button className="btn-primary btn-primary--accent" type="submit" disabled={isLoading}>
                                    {isLoading ? 'Verifying...' : 'Verify Code'}
                                </button>
                            </form>
                            <div style={{ ...s.footer, display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                                <button
                                    onClick={() => { setStep('email'); setError(''); }}
                                    style={{ background: 'none', border: 'none', color: 'rgba(255,255,255,0.3)', cursor: 'pointer', fontSize: '0.8rem' }}
                                >
                                    ← Back
                                </button>
                            </div>
                        </motion.div>
                    )}

                    {step === 'new_password' && (
                        <motion.div
                            key="new_password"
                            className="glass-card"
                            style={s.card}
                            initial={{ opacity: 0, y: 15, scale: 0.98 }}
                            animate={{ opacity: 1, y: 0, scale: 1 }}
                            exit={{ opacity: 0, y: -10, scale: 0.98 }}
                            transition={{ duration: 0.45 }}
                        >
                            <div style={s.header}>
                                <h2 style={s.title}>Create New Password</h2>
                                <p style={s.sub}>Set a strong password for your account</p>
                            </div>
                            {error && <div style={s.errorBadge}>{error}</div>}
                            <form style={s.form} onSubmit={handleResetPassword}>
                                <div style={s.group}>
                                    <label className="form-label">New Password</label>
                                    <input
                                        type="password"
                                        className="form-input"
                                        placeholder="Enter new password"
                                        value={newPassword}
                                        onChange={(e) => setNewPassword(e.target.value)}
                                        required
                                    />
                                </div>
                                <div style={s.group}>
                                    <label className="form-label">Confirm Password</label>
                                    <input
                                        type="password"
                                        className="form-input"
                                        placeholder="Confirm new password"
                                        value={confirmPassword}
                                        onChange={(e) => setConfirmPassword(e.target.value)}
                                        required
                                    />
                                </div>
                                <button className="btn-primary btn-primary--accent" type="submit" disabled={isLoading}>
                                    {isLoading ? 'Resetting...' : 'Reset Password'}
                                </button>
                            </form>
                        </motion.div>
                    )}

                    {step === 'success' && (
                        <motion.div
                            key="success"
                            className="glass-card"
                            style={{ ...s.card, textAlign: 'center' }}
                            initial={{ opacity: 0, scale: 0.9 }}
                            animate={{ opacity: 1, scale: 1 }}
                            transition={{ duration: 0.4 }}
                        >
                            <motion.div
                                initial={{ scale: 0 }}
                                animate={{ scale: 1 }}
                                transition={{ delay: 0.2, type: 'spring', stiffness: 200 }}
                            >
                                <CheckCircle2 size={64} color="#10b981" style={{ margin: '0 auto 1.5rem auto' }} />
                            </motion.div>
                            <h2 style={s.title}>Password Reset!</h2>
                            <p style={s.sub}>Your password has been successfully updated.</p>
                            <p style={{ ...s.sub, marginTop: '1rem', color: '#818cf8' }}>Redirecting to login...</p>
                        </motion.div>
                    )}
                </AnimatePresence>
            </div>
            <HackerLoader isVisible={isLoading} />
        </div>
    );
};

const s = {
    card: { width: '100%', maxWidth: '400px', padding: '2.75rem 2.25rem' },
    header: { textAlign: 'center', marginBottom: '2rem' },
    iconWrap: { display: 'flex', justifyContent: 'center', marginBottom: '1rem' },
    title: { fontSize: '1.65rem', fontWeight: 800, color: '#ededed', letterSpacing: '-0.5px', marginBottom: '0.25rem' },
    sub: { color: 'rgba(255,255,255,0.35)', fontSize: '0.85rem' },
    form: { display: 'flex', flexDirection: 'column', gap: '1.5rem' },
    group: { display: 'flex', flexDirection: 'column', gap: '0.65rem' },
    footer: { marginTop: '1.75rem', textAlign: 'center', fontSize: '0.85rem', color: 'rgba(255,255,255,0.3)' },
    errorBadge: {
        backgroundColor: 'rgba(239, 68, 68, 0.1)',
        color: '#ef4444',
        padding: '0.75rem',
        borderRadius: '0.5rem',
        fontSize: '0.85rem',
        textAlign: 'center',
        marginBottom: '1rem',
        border: '1px solid rgba(239, 68, 68, 0.2)'
    },
    otpBox: {
        width: '56px',
        height: '64px',
        textAlign: 'center',
        fontSize: '1.5rem',
        fontWeight: 800,
        color: '#ffffff',
        background: 'rgba(255,255,255,0.05)',
        border: '1px solid rgba(255,255,255,0.12)',
        borderRadius: '12px',
        outline: 'none',
        caretColor: '#818cf8',
    }
};

export default ForgotPassword;
