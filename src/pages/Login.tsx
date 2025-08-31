// src/components/auth/LoginForm.tsx
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { LoginFormData, LoginZodObject, SignupFormData, SignupZodObject } from "@/types/auth.types";
import { useLogin } from "@/hooks/auth/useLogin";
import { useSignup } from "@/hooks/auth/useSignup";

export const LoginForm = () => {
    const { mutate: loginViaMutation, isPending: isLoggingInViaMutation } = useLogin();
    const { mutate: signupViaMutation, isPending: isSigningUpViaMutation } = useSignup();

    const form = useForm<LoginFormData>({
        resolver: zodResolver(LoginZodObject),
        defaultValues: { email: "", password: "" },
    });

    const signupForm = useForm<SignupFormData>({
        resolver: zodResolver(SignupZodObject),
        defaultValues: { email: "", password: "", confirmPassword: "" },
    });

    const onSubmit = (values: LoginFormData) => {
        loginViaMutation(values);
    };

    const onSignupSubmit = (values: SignupFormData) => {
        signupViaMutation(values);
    };

    return (
        <div className="flex flex-col items-center justify-center h-screen">
            {/* // login Form */}
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
                <input type="email" placeholder="Email" {...form.register("email")} />
                <input type="password" placeholder="Password" {...form.register("password")} />
                <button type="submit" disabled={isLoggingInViaMutation}>
                    {isLoggingInViaMutation ? "Logging in..." : "Login"}
                </button>
            </form>
            {/* Signup Form */}
            <form onSubmit={signupForm.handleSubmit(onSignupSubmit)} className="space-y-4">
                <input type="email" placeholder="Email" {...signupForm.register("email")} />
                <input type="password" placeholder="Password" {...signupForm.register("password")} />
                <input type="password" placeholder="Confirm Password" {...signupForm.register("confirmPassword")} />
                <button type="submit" disabled={isSigningUpViaMutation}>
                    {isSigningUpViaMutation ? "Signing up..." : "Signup"}
                </button>
            </form>
        </div>
    );
};
