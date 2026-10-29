"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { ArrowLeft, MailCheck } from "lucide-react";
import Link from "next/link";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { AuthHeading } from "@/components/app/AuthCard";
import { Button } from "@/components/ui/Button";
import { InlineAlert } from "@/components/ui/Feedback";
import { Field, Input } from "@/components/ui/Form";
import { api } from "@/lib/api";

const schema = z.object({ email: z.email("Enter a valid email address.") });
type Values = z.infer<typeof schema>;

export default function ForgotPasswordPage() {
  const [result, setResult] = useState<{ message: string; email_delivery_configured: boolean } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<Values>({ resolver: zodResolver(schema) });

  const onSubmit = async (values: Values) => {
    setError(null);
    try {
      setResult(await api("/auth/forgot-password", { method: "POST", body: values, auth: false }));
    } catch (e) {
      setError((e as Error).message);
    }
  };

  return (
    <>
      <AuthHeading title="Reset your password" description="Enter your account email and we'll send you a reset link." />
      {result ? (
        result.email_delivery_configured ? (
          <div className="card flex gap-3 p-4">
            <MailCheck size={18} className="mt-0.5 shrink-0 text-success" aria-hidden="true" />
            <div>
              <p className="text-body font-medium">Check your inbox</p>
              <p className="mt-1 text-body text-fg-muted">{result.message} The link expires in 30 minutes.</p>
            </div>
          </div>
        ) : (
          <InlineAlert tone="warning">{result.message}</InlineAlert>
        )
      ) : (
        <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4" noValidate>
          {error && <InlineAlert>{error}</InlineAlert>}
          <Field label="Email" error={errors.email?.message}>
            {(p) => <Input {...p} type="email" autoComplete="email" placeholder="you@company.com" {...register("email")} />}
          </Field>
          <Button type="submit" variant="primary" size="lg" loading={isSubmitting} className="w-full">
            Send reset link
          </Button>
        </form>
      )}
      <Link href="/login" className="mt-6 inline-flex items-center gap-1.5 text-body text-fg-muted hover:text-fg">
        <ArrowLeft size={15} /> Back to sign in
      </Link>
    </>
  );
}
