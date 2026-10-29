"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { AuthHeading, safeNext } from "@/components/app/AuthCard";
import { PasswordInput } from "@/components/app/PasswordInput";
import { Button } from "@/components/ui/Button";
import { InlineAlert } from "@/components/ui/Feedback";
import { Field, Input } from "@/components/ui/Form";
import { useAuth } from "@/lib/auth";

const schema = z.object({
  email: z.email("Enter a valid email address."),
  password: z.string().min(1, "Enter your password."),
});
type Values = z.infer<typeof schema>;

export function LoginForm() {
  const { login, status } = useAuth();
  const router = useRouter();
  const params = useSearchParams();
  const next = safeNext(params.get("next"));
  const [error, setError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<Values>({ resolver: zodResolver(schema) });

  useEffect(() => {
    if (status === "authenticated") router.replace(next);
  }, [status, next, router]);

  const onSubmit = async (values: Values) => {
    setError(null);
    try {
      await login(values.email, values.password);
      router.replace(next);
    } catch (e) {
      setError((e as Error).message);
    }
  };

  return (
    <>
      <AuthHeading title="Welcome back" description="Sign in to manage your workflows." />
      {params.get("reset") === "1" && (
        <InlineAlert tone="success" className="mb-4">
          Your password was reset. Sign in with your new password.
        </InlineAlert>
      )}
      {params.get("expired") === "1" && !error && (
        <InlineAlert tone="info" className="mb-4">
          Your session ended. Please sign in again.
        </InlineAlert>
      )}
      <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4" noValidate>
        {error && <InlineAlert>{error}</InlineAlert>}
        <Field label="Email" error={errors.email?.message}>
          {(p) => <Input {...p} type="email" autoComplete="email" placeholder="you@company.com" {...register("email")} />}
        </Field>
        <Field
          label="Password"
          error={errors.password?.message}
        >
          {(p) => <PasswordInput {...p} autoComplete="current-password" {...register("password")} />}
        </Field>
        <div className="-mt-1 flex justify-end">
          <Link href="/forgot-password" className="text-meta text-violet hover:underline">
            Forgot password?
          </Link>
        </div>
        <Button type="submit" variant="primary" size="lg" loading={isSubmitting} className="w-full">
          Sign in
        </Button>
      </form>
      <p className="mt-6 text-center text-body text-fg-muted">
        New to GhostWork?{" "}
        <Link href="/register" className="font-medium text-violet hover:underline">
          Create an account
        </Link>
      </p>
    </>
  );
}
