"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useForm, useWatch } from "react-hook-form";
import { z } from "zod";
import { AuthHeading } from "@/components/app/AuthCard";
import { PasswordInput, PasswordStrength, passwordProblems } from "@/components/app/PasswordInput";
import { Button } from "@/components/ui/Button";
import { InlineAlert } from "@/components/ui/Feedback";
import { Field, Input } from "@/components/ui/Form";
import { useAuth } from "@/lib/auth";
import { TermsAgreement } from "./TermsAgreement";

const schema = z.object({
  fullName: z.string().trim().min(1, "Enter your name.").max(120),
  email: z.email("Enter a valid email address."),
  password: z.string().superRefine((value, ctx) => {
    const problem = passwordProblems(value);
    if (problem) ctx.addIssue({ code: "custom", message: problem });
  }),
  acceptTerms: z.boolean().refine((v) => v, "Please read and accept the Terms of Service to continue."),
});
type Values = z.infer<typeof schema>;

export default function RegisterPage() {
  const { register: createAccount, status } = useAuth();
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    control,
    formState: { errors, isSubmitting },
  } = useForm<Values>({ resolver: zodResolver(schema), defaultValues: { password: "", acceptTerms: false } });
  const passwordValue = useWatch({ control, name: "password" }) ?? "";

  useEffect(() => {
    if (status === "authenticated") router.replace("/dashboard");
  }, [status, router]);

  const onSubmit = async (values: Values) => {
    setError(null);
    try {
      await createAccount(values.fullName, values.email, values.password, values.acceptTerms);
      router.replace("/dashboard");
    } catch (e) {
      setError((e as Error).message);
    }
  };

  return (
    <>
      <AuthHeading title="Create your account" description="Start automating in a couple of minutes." />
      <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4" noValidate>
        {error && <InlineAlert>{error}</InlineAlert>}
        <Field label="Full name" error={errors.fullName?.message}>
          {(p) => <Input {...p} autoComplete="name" placeholder="Ada Lovelace" {...register("fullName")} />}
        </Field>
        <Field label="Work email" error={errors.email?.message}>
          {(p) => <Input {...p} type="email" autoComplete="email" placeholder="you@company.com" {...register("email")} />}
        </Field>
        <Field label="Password" error={errors.password?.message} hint="At least 10 characters, with a letter and a number.">
          {(p) => (
            <div>
              <PasswordInput {...p} autoComplete="new-password" {...register("password")} />
              <PasswordStrength value={passwordValue} />
            </div>
          )}
        </Field>
        <TermsAgreement
          error={errors.acceptTerms?.message}
          registerProps={register("acceptTerms")}
        />
        <Button type="submit" variant="primary" size="lg" loading={isSubmitting} className="mt-1 w-full">
          Create account
        </Button>
      </form>
      <p className="mt-6 text-center text-body text-fg-muted">
        Already have an account?{" "}
        <Link href="/login" className="font-medium text-violet hover:underline">
          Sign in
        </Link>
      </p>
    </>
  );
}
