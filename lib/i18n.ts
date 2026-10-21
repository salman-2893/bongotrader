import { getRequestConfig } from 'next-intl/server';
import en from '../messages/en.json';
import bn from '../messages/bn.json';

export default getRequestConfig(async ({ requestLocale }) => {
  let locale = await requestLocale;

  // যদি কোনো কারণে locale না পাওয়া যায়, তবে ডিফল্ট 'en' সেট হবে
  if (!locale || !['en', 'bn'].includes(locale)) {
    locale = 'en';
  }

  // locale অনুযায়ী মেসেজ সিলেক্ট করা
  const messages = locale === 'bn' ? bn : en;

  return {
    locale,
    messages
  };
});v