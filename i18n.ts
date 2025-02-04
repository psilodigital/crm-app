import { getRequestConfig } from "next-intl/server";

export default getRequestConfig(async ({ locale: requestLocale }) => ({
  messages: (await import(`./locales/${requestLocale}.json`)).default,
  timeZone: "Europe/Prague",
}));
