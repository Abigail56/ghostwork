"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { AuthHeading } from "@/components/app/AuthCard";
import { PasswordInput, PasswordStrength, passwordProblems } from "@/components/app/PasswordInput";
import { Button } from "@/components/ui/Button";
import { InlineAlert } from "@/components/ui/Feedback";
import { Field } from "@/components/ui/Form";
import { api } from "@/lib/api";

const schema = z
  .object({
    password: z.string().superRefine((value, ctx) => {
      const problem = passwordProblems(value);
      if (problem) ctx.addIssue({ code: "custom", message: problem });
    }),
    confirm: z.string(),
  })
  .refine((v) => v.password === v.confirm, { path: ["confirm"], message: "Passwords don't match." });
type Values = z.infer<typeof schema>;

export function ResetForm() {
  const params = useSearchParams();
  const router = useRouter();
  const token = params.get("token");
  const [error, setError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<Values>({ resolver: zodResolver(schema), defaultValues: { password: "", confirm: "" } });

  if (!token) {
    return (
      <>
        <AuthHeading title="Reset link missing" />
        <InlineAlert tone="warning">This page needs the link from your reset email. Request a new one to continue.</InlineAlert>
        <Link href="/forgot-password" className="mt-6 inline-block text-body text-violet hover:underline">
          Request a reset link
        </Link>
      </>
    );
  }

  const onSubmit = async (values: Values) => {
    setError(null);
    try {
      await api("/auth/reset-password", { method: "POST", body: { token, password: values.password }, auth: false });
      router.replace("/login?reset=1");
    } catch (e) {
      setError((e as Error).message);
    }
  };

  return (
    <>
      <AuthHeading title="Choose a new password" description="You'll be signed out of every device after the change." />
      <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4" noValidate>
        {error && (
          <InlineAlert>
            {error}{" "}
            <Link href="/forgot-password" className="underline">
              Request a new link
            </Link>
          </InlineAlert>
        )}
        <Field label="New password" error={errors.password?.message}>
          {(p) => (
            <div>
              <PasswordInput {...p} autoComplete="new-password" {...register("password")} />
              <PasswordStrength value={watch("password")} />
            </div>
          )}
        </Field>
        <Field label="Confirm password" error={errors.confirm?.message}>
          {(p) => <PasswordInput {...p} autoComplete="new-password" {...register("confirm")} />}
        </Field>
        <Button type="submit" variant="primary" size="lg" loading={isSubmitting} className="w-full">
          Update password
        </Button>
      </form>
    </>
  );
}
