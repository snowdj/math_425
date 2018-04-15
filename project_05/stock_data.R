library(tidyquant)

stocks <- c("^GSPC", "AAPL", "JBLU", "BBY", "GM", "AMZN") %>% 
  tq_get() %>% 
  select(date, symbol, adjusted) %>% 
  group_by(symbol) %>% 
  tq_transmute(select     = adjusted, 
               mutate_fun = periodReturn, 
               period     = "daily", 
               type       = "log",
               col_rename = "daily.returns")

stocks %>% 
  ggplot(aes(x = daily.returns)) + 
  geom_histogram(aes(y=..density..),color = "white", fill = "#00203b", bins = 50) + 
  geom_density(aes(y=..density..), color = "firebrick2", size = .5) +
  facet_wrap(~ symbol, scales = "free") +
  theme_classic()

stocks.wide <- stocks %>% 
  spread(key = symbol, value = daily.returns)

stocks.wide %>% 
  ggplot(aes(x = `^GSPC`, y = AAPL)) + 
  geom_point(alpha = .3, size = 1.5) + 
  geom_smooth(method = "lm", se = FALSE, color = "firebrick2") + 
  scale_x_continuous(labels = scales::percent) + 
  scale_y_continuous(labels = scales::percent) + 
  labs(title = "Visualizing Returns Relationship: AAPL vs SPX 500", 
       x = "SPX 500") + 
  theme_classic()

aapl.spx <- lm(AAPL ~ `^GSPC`, data = stocks.wide)

pander::pander(summary(aapl.spx))


aapl.jblu <- lm(AAPL ~ JBLU, data = stocks.wide) %>% 
  summary() %>% 
  pander::pander()

aapl.bby <- lm(AAPL ~ BBY, data = stocks.wide) %>% 
  summary() %>% 
  pander::pander()

aapl.gm <- lm(AAPL ~ GM, data = stocks.wide) %>% 
  summary() %>% 
  pander::pander()

aapl.amzn <- lm(AAPL ~ AMZN, data = stocks.wide) %>% 
  summary() %>% 
  pander::pander()

plot(lm(AAPL ~ AMZN, data = stocks.wide))
